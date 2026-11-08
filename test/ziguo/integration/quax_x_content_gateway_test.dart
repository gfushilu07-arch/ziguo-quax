import 'dart:async';
import 'dart:io' show SocketException;

import 'package:dart_twitter_api/twitter_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:quax/catcher/exceptions.dart';
import 'package:quax/client/client.dart';
import 'package:quax/ziguo/domain/content_access_exception.dart';
import 'package:quax/ziguo/domain/resolved_content.dart';
import 'package:quax/ziguo/domain/source_ref.dart';
import 'package:quax/ziguo/integration/quax/quax_x_content_gateway.dart';

import '../domain/source_ref_test.dart' show refJson;

TweetWithCard tweet({String id = '2109404168712823282'}) => TweetWithCard()
  ..idStr = id
  ..fullText = '甲😀\n乙'
  ..user = (User()
    ..idStr = '123'
    ..screenName = 'example'
    ..name = 'Example')
  ..extendedEntities = Entities.fromJson({
    'media': [
      {
        'id_str': '10',
        'type': 'photo',
        'media_url_https': 'https://pbs.twimg.com/first.jpg',
      },
      {
        'id_str': '2109404168712823200',
        'type': 'video',
        'media_url_https': 'https://pbs.twimg.com/poster.jpg',
        'video_info': {
          'aspect_ratio': [9, 16],
          'variants': [
            {
              'content_type': 'video/mp4',
              'bitrate': 256000,
              'url': 'https://video.twimg.com/low.mp4',
            },
            {
              'content_type': 'video/mp4',
              'bitrate': 832000,
              'url': 'https://video.twimg.com/high.mp4',
            },
          ],
        },
      },
    ],
  });
TweetStatus status(List<TweetWithCard> tweets) => TweetStatus(
  chains: [TweetChain(id: 'test', tweets: tweets, isPinned: false)],
  cursorBottom: null,
  cursorTop: null,
);
TypeMatcher<ContentAccessException> accessError(ContentAccessCode code) =>
    isA<ContentAccessException>().having((e) => e.code, 'code', code);

void main() {
  test('finds focal post and explicit media, never first item', () async {
    final gateway = QuaXXContentGateway(
      loadTweet: (_) async => status([tweet(id: '999'), tweet()]),
    );
    final result = await gateway.resolve(
      SourceRef.fromJson(refJson(kind: 'video')),
    ) as ResolvedVideo;
    expect(result.mediaId, '2109404168712823200');
    expect(result.variants.first.uri.path, '/high.mp4');
    expect(result.aspectRatio, 9 / 16);
  });
  test('keeps complete Chinese and emoji text', () async {
    final gateway = QuaXXContentGateway(
      loadTweet: (_) async => status([tweet()]),
    );
    expect(
      (await gateway.resolve(
        SourceRef.fromJson(refJson()),
      ) as ResolvedText).text,
      '甲😀\n乙',
    );
  });
  test(
    'rejects preview, empty body, missing target and changed media',
    () async {
      for (final entry in [
        (
          tweet()..isSubscriberPreview = true,
          ContentAccessCode.sourceIncomplete,
        ),
        (tweet()..fullText = '', ContentAccessCode.sourceIncomplete),
        (tweet(id: '999'), ContentAccessCode.sourceIncomplete),
        (tweet()..isTombstone = true, ContentAccessCode.sourceMissing),
      ]) {
        final gateway = QuaXXContentGateway(
          loadTweet: (_) async => status([entry.$1]),
        );
        await expectLater(
          gateway.resolve(SourceRef.fromJson(refJson())),
          throwsA(accessError(entry.$2)),
        );
      }
      final gateway = QuaXXContentGateway(
        loadTweet: (_) async => status([tweet()]),
      );
      await expectLater(
        gateway.resolve(
          SourceRef.fromJson({...refJson(kind: 'video'), 'media_id': '999'}),
        ),
        throwsA(accessError(ContentAccessCode.sourceChanged)),
      );
      await expectLater(
        gateway.resolve(
          SourceRef.fromJson({...refJson(), 'publisher_user_id': '999'}),
        ),
        throwsA(accessError(ContentAccessCode.sourceChanged)),
      );
    },
  );
  test(
    'rejects subscriber previews even for media and non-embeddable video',
    () async {
      final restricted = tweet()..isSubscriberPreview = true;
      final gateway = QuaXXContentGateway(
        loadTweet: (_) async => status([restricted]),
      );
      await expectLater(
        gateway.resolve(SourceRef.fromJson(refJson(kind: 'video'))),
        throwsA(accessError(ContentAccessCode.sourceIncomplete)),
      );
      final video = tweet();
      video.extendedEntities!.media![1].additionalMediaInfo =
          AdditionalMediaInfo.fromJson({'embeddable': false});
      await expectLater(
        QuaXXContentGateway(loadTweet: (_) async => status([video]))
            .resolve(SourceRef.fromJson(refJson(kind: 'video'))),
        throwsA(accessError(ContentAccessCode.forbidden)),
      );
    },
  );
  test(
    'maps failures without leaking original response or credentials',
    () async {
      final failures = <(Object, ContentAccessCode)>[
        (
          SessionRejectedException('private-account'),
          ContentAccessCode.authRequired,
        ),
        (NoAccountAvailableException(), ContentAccessCode.authRequired),
        (
          RateLimitedException(DateTime.utc(2026, 11, 9)),
          ContentAccessCode.rateLimited,
        ),
        (
          HttpException(http.Response('secret response', 403)),
          ContentAccessCode.forbidden,
        ),
        (
          HttpException(http.Response('secret response', 429)),
          ContentAccessCode.rateLimited,
        ),
        (const SocketException('secret host'), ContentAccessCode.networkError),
        (TimeoutException('secret request'), ContentAccessCode.networkError),
        (NotFoundException(), ContentAccessCode.sourceMissing),
      ];
      for (final entry in failures) {
        final gateway = QuaXXContentGateway(
          loadTweet: (_) async => throw entry.$1,
        );
        await expectLater(
          gateway.resolve(SourceRef.fromJson(refJson())),
          throwsA(
            accessError(entry.$2).having(
              (e) => e.toString(),
              'redacted',
              isNot(contains('secret')),
            ),
          ),
        );
      }
    },
  );
  test(
    'refresh performs a new read; discoveries contain metadata only',
    () async {
      var count = 0;
      final gateway = QuaXXContentGateway(
        loadTweet: (_) async {
          count++;
          return status([tweet()]);
        },
      );
      final source = SourceRef.fromJson(refJson());
      await gateway.resolve(source);
      await gateway.resolve(source, refresh: true);
      expect(count, 2);
      final refs = await gateway.inspectPost(source.postId);
      expect(refs.map((r) => r.representation), [
        ContentRepresentation.text,
        ContentRepresentation.image,
        ContentRepresentation.video,
      ]);
      expect(refs.expand((r) => r.toJson().keys), isNot(contains('text')));
      expect(
        refs
            .expand((r) => r.toJson().values)
            .whereType<String>()
            .any((v) => v.startsWith('https://')),
        isFalse,
      );
    },
  );
}
