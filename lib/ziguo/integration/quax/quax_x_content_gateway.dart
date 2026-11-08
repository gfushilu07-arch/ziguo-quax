import 'dart:async';
import 'dart:io' show SocketException, HandshakeException;

import 'package:quax/catcher/exceptions.dart';
import 'package:quax/client/client.dart';
import 'package:uuid/uuid.dart';

import '../../domain/content_access_exception.dart';
import '../../domain/resolved_content.dart';
import '../../domain/source_ref.dart';
import '../../domain/x_content_gateway.dart';
import 'quax_content_mapper.dart';

final class QuaXXContentGateway implements XContentGateway, XContentInspector {
  final Future<TweetStatus> Function(String) loadTweet;
  QuaXXContentGateway({required this.loadTweet});

  Future<TweetStatus> _load(String postId) async {
    if (!RegExp(r'^[0-9]+$').hasMatch(postId)) {
      throw const FormatException('Invalid post ID');
    }
    try {
      return await loadTweet(postId).timeout(const Duration(seconds: 40));
    } on ContentAccessException {
      rethrow;
    } on NoAccountAvailableException {
      throw const ContentAccessException(ContentAccessCode.authRequired);
    } on SessionRejectedException {
      throw const ContentAccessException(ContentAccessCode.authRequired);
    } on RateLimitedException catch (error) {
      throw ContentAccessException(
        ContentAccessCode.rateLimited,
        retryAt: error.availableAt,
      );
    } on NotFoundException {
      throw const ContentAccessException(ContentAccessCode.sourceMissing);
    } on HttpException catch (error) {
      final code = switch (error.statusCode) {
        401 => ContentAccessCode.authRequired,
        403 => ContentAccessCode.forbidden,
        404 => ContentAccessCode.sourceMissing,
        429 => ContentAccessCode.rateLimited,
        _ => ContentAccessCode.networkError,
      };
      final seconds = int.tryParse(
        error.response.headers['x-rate-limit-reset'] ?? '',
      );
      throw ContentAccessException(
        code,
        retryAt: seconds == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true),
      );
    } on SocketException {
      throw const ContentAccessException(ContentAccessCode.networkError);
    } on HandshakeException {
      throw const ContentAccessException(ContentAccessCode.networkError);
    } on TimeoutException {
      throw const ContentAccessException(ContentAccessCode.networkError);
    } catch (_) {
      // Raw upstream exceptions can contain response bodies; never pass those to UI/logs.
      throw const ContentAccessException(ContentAccessCode.sourceIncomplete);
    }
  }

  @override
  Future<ResolvedContent> resolve(
    SourceRef source, {
    bool refresh = false,
  }) async {
    // No persistent cache: every call (including refresh) loads the current post.
    return mapQuaXContent(source, await _load(source.postId));
  }

  @override
  Future<List<SourceRef>> inspectPost(String postId) async {
    final tweet = focalTweet(postId, await _load(postId));
    SourceRef ref(ContentRepresentation kind, {String? mediaId, int? index}) =>
        SourceRef.fromJson({
          'id': const Uuid().v5(
            Namespace.url.value,
            'https://x.com/i/status/$postId#${kind.name}:${mediaId ?? "text"}',
          ),
          'provider': 'x',
          'post_id': postId,
          'representation': kind.name,
          'revision': 1,
          'media_id': ?mediaId,
          'media_index': ?index,
          if (tweet.user?.idStr != null) 'publisher_user_id': tweet.user!.idStr,
        });
    final result = <SourceRef>[];
    if (tweet.article == null &&
        tweet.noteText == null &&
        tweet.truncated != true &&
        (tweet.fullText?.trim().isNotEmpty ?? false)) {
      result.add(ref(ContentRepresentation.text));
    }
    final media = postMedia(tweet);
    for (var index = 0; index < media.length; index++) {
      final item = media[index];
      if (item.idStr == null) continue;
      if (item.type == 'photo') {
        result.add(
          ref(ContentRepresentation.image, mediaId: item.idStr, index: index),
        );
      }
      if (item.type == 'video' || item.type == 'animated_gif') {
        result.add(
          ref(ContentRepresentation.video, mediaId: item.idStr, index: index),
        );
      }
    }
    return List.unmodifiable(result);
  }
}
