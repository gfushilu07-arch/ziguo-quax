import 'package:dart_twitter_api/twitter_api.dart';
import 'package:quax/client/client.dart';

import '../../domain/content_access_exception.dart';
import '../../domain/resolved_content.dart';
import '../../domain/source_ref.dart';

TweetWithCard focalTweet(String postId, TweetStatus status) {
  if (status.error != null) {
    throw const ContentAccessException(ContentAccessCode.sourceIncomplete);
  }
  for (final chain in status.chains) {
    for (final tweet in chain.tweets) {
      if (tweet.idStr != postId) continue;
      if (tweet.isTombstone == true) {
        throw const ContentAccessException(ContentAccessCode.sourceMissing);
      }
      if (tweet.isSubscriberPreview) {
        throw const ContentAccessException(ContentAccessCode.sourceIncomplete);
      }
      return tweet;
    }
  }
  // An empty parsed response is not evidence that the post was deleted.
  throw const ContentAccessException(ContentAccessCode.sourceIncomplete);
}

List<Media> postMedia(TweetWithCard tweet) =>
    tweet.extendedEntities?.media ?? tweet.entities?.media ?? [];

Uri? xMediaUri(String? value) {
  final uri = value == null ? null : Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort) {
    return null;
  }
  final host = uri.host.toLowerCase();
  return [
        'twimg.com',
        'x.com',
        'twitter.com',
      ].any((domain) => host == domain || host.endsWith('.$domain'))
      ? uri
      : null;
}

ResolvedContent mapQuaXContent(SourceRef source, TweetStatus status) {
  final tweet = focalTweet(source.postId, status);
  if (source.publisherUserId != null &&
      source.publisherUserId != tweet.user?.idStr) {
    throw const ContentAccessException(ContentAccessCode.sourceChanged);
  }
  final authorName = tweet.user?.name ?? '';
  final authorHandle = tweet.user?.screenName ?? '';
  if (source.representation == ContentRepresentation.text) {
    if (tweet.article != null || tweet.noteText != null) {
      throw const ContentAccessException(ContentAccessCode.unsupported);
    }
    final text = tweet.fullText;
    if (text == null || text.trim().isEmpty || tweet.truncated == true) {
      throw const ContentAccessException(ContentAccessCode.sourceIncomplete);
    }
    return ResolvedText(
      source,
      text,
      authorName: authorName,
      authorHandle: authorHandle,
    );
  }
  final media = postMedia(tweet);
  final index = media.indexWhere((item) => item.idStr == source.mediaId);
  if (index < 0 || (source.mediaIndex != null && source.mediaIndex != index)) {
    throw const ContentAccessException(ContentAccessCode.sourceChanged);
  }
  final selected = media[index];
  if (source.representation == ContentRepresentation.image) {
    final uri = xMediaUri(selected.mediaUrlHttps);
    if (selected.type != 'photo' || uri == null) {
      throw const ContentAccessException(ContentAccessCode.sourceChanged);
    }
    return ResolvedImage(
      source,
      mediaId: selected.idStr!,
      uri: uri,
      authorName: authorName,
      authorHandle: authorHandle,
    );
  }
  if (selected.type != 'video' && selected.type != 'animated_gif') {
    throw const ContentAccessException(ContentAccessCode.sourceChanged);
  }
  if (selected.additionalMediaInfo?.embeddable == false) {
    throw const ContentAccessException(ContentAccessCode.forbidden);
  }
  final variants = <VideoVariant>[];
  for (final variant in selected.videoInfo?.variants ?? <Variant>[]) {
    final uri = xMediaUri(variant.url);
    final mime = variant.contentType;
    if (uri != null &&
        (mime == 'video/mp4' ||
            mime == 'application/x-mpegURL' ||
            mime == 'application/vnd.apple.mpegurl')) {
      variants.add(VideoVariant(uri, mime!, variant.bitrate));
    }
  }
  variants.sort((a, b) {
    final format =
        (b.mimeType == 'video/mp4' ? 1 : 0) -
        (a.mimeType == 'video/mp4' ? 1 : 0);
    return format != 0 ? format : (b.bitrate ?? 0).compareTo(a.bitrate ?? 0);
  });
  if (variants.isEmpty) {
    throw const ContentAccessException(ContentAccessCode.sourceIncomplete);
  }
  final ratio = selected.videoInfo?.aspectRatio;
  final aspect =
      ratio != null && ratio.length == 2 && ratio[0] > 0 && ratio[1] > 0
      ? ratio[0] / ratio[1]
      : 9 / 16;
  return ResolvedVideo(
    source,
    mediaId: selected.idStr!,
    variants: List.unmodifiable(variants),
    aspectRatio: aspect,
    authorName: authorName,
    authorHandle: authorHandle,
  );
}
