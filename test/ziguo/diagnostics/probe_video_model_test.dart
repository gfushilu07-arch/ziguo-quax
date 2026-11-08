import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/ziguo/domain/resolved_content.dart';
import 'package:quax/ziguo/domain/source_ref.dart';
import 'package:quax/ziguo/domain/x_content_gateway.dart';
import 'package:quax/ziguo/features/diagnostics/probe_playback.dart';
import 'package:quax/ziguo/features/diagnostics/probe_video_model.dart';

import '../domain/source_ref_test.dart' show refJson;

class FakePlayback implements ProbePlayback {
  bool disposed = false;
  late void Function(PlaybackFailure) fail;
  @override
  Future<void> initialize(
    ResolvedVideo video,
    void Function(PlaybackFailure) onFailure,
  ) async {
    fail = onFailure;
  }

  @override
  Widget buildView() => const SizedBox();
  @override
  void dispose() {
    disposed = true;
  }
}

class VideoGateway implements XContentGateway {
  final ResolvedVideo video;
  int refreshes = 0;
  VideoGateway(this.video);
  @override
  Future<ResolvedContent> resolve(
    SourceRef source, {
    bool refresh = false,
  }) async {
    if (refresh) refreshes++;
    return video;
  }
}

void main() {
  final video = ResolvedVideo(
    SourceRef.fromJson(refJson(kind: 'video')),
    mediaId: '2109404168712823200',
    variants: [
      VideoVariant(
        Uri.parse('https://video.twimg.com/test.mp4'),
        'video/mp4',
        1,
      ),
    ],
  );
  test('disposes old player when switching and on close', () async {
    final players = <FakePlayback>[];
    final model = ProbeVideoModel(
      gateway: VideoGateway(video),
      createPlayback: () {
        final player = FakePlayback();
        players.add(player);
        return player;
      },
    );
    await model.open(video);
    await model.open(video);
    expect(players.first.disposed, isTrue);
    expect(players.last.disposed, isFalse);
    model.close();
    expect(players.last.disposed, isTrue);
  });
  test(
    'expired source refreshes once then stops, stale callbacks are ignored',
    () async {
      final gateway = VideoGateway(video);
      final players = <FakePlayback>[];
      final model = ProbeVideoModel(
        gateway: gateway,
        createPlayback: () {
          final player = FakePlayback();
          players.add(player);
          return player;
        },
      );
      await model.open(video);
      players.first.fail(PlaybackFailure.sourceUnavailable);
      await Future<void>.delayed(Duration.zero);
      expect(players.first.disposed, isTrue);
      expect(gateway.refreshes, 1);
      expect(players.length, 2);
      players.first.fail(PlaybackFailure.sourceUnavailable);
      players.last.fail(PlaybackFailure.sourceUnavailable);
      await Future<void>.delayed(Duration.zero);
      expect(gateway.refreshes, 1);
      expect(model.state.error, isNotNull);
      expect(players.every((player) => player.disposed), isTrue);
      model.close();
    },
  );
  test('decoder failure does not trigger a network refresh', () async {
    final gateway = VideoGateway(video);
    final player = FakePlayback();
    final model = ProbeVideoModel(
      gateway: gateway,
      createPlayback: () => player,
    );
    await model.open(video);
    player.fail(PlaybackFailure.other);
    await Future<void>.delayed(Duration.zero);
    expect(gateway.refreshes, 0);
    expect(player.disposed, isTrue);
    model.close();
  });
}
