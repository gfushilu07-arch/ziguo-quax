import 'package:flutter_triple/flutter_triple.dart';

import '../../domain/content_access_exception.dart';
import '../../domain/resolved_content.dart';
import '../../domain/x_content_gateway.dart';
import 'probe_playback.dart';

class ProbeVideoState {
  final ProbePlayback? playback;
  final String? error;
  const ProbeVideoState({this.playback, this.error});
}

class ProbeVideoModel extends Store<ProbeVideoState> {
  final XContentGateway gateway;
  final ProbePlayback Function() createPlayback;
  ProbePlayback? _playback;
  int _generation = 0;
  bool _closed = false;
  bool _refreshUsed = false;
  ProbeVideoModel({required this.gateway, required this.createPlayback})
    : super(const ProbeVideoState());

  Future<void> open(ResolvedVideo video) async {
    final generation = ++_generation;
    _refreshUsed = false;
    _playback?.dispose();
    _playback = null;
    update(const ProbeVideoState());
    await _start(video, generation);
  }

  Future<void> _start(ResolvedVideo video, int generation) async {
    if (_closed || generation != _generation) return;
    final playback = createPlayback();
    _playback = playback;
    update(ProbeVideoState(playback: playback));
    try {
      await playback.initialize(video, (failure) {
        if (!_closed &&
            generation == _generation &&
            identical(_playback, playback)) {
          _failed(video, generation, failure);
        }
      });
    } catch (_) {
      if (!_closed &&
          generation == _generation &&
          identical(_playback, playback)) {
        await _failed(video, generation, PlaybackFailure.other);
      }
    }
  }

  Future<void> _failed(
    ResolvedVideo video,
    int generation,
    PlaybackFailure failure,
  ) async {
    _playback?.dispose();
    _playback = null;
    update(const ProbeVideoState());
    if (_refreshUsed || failure != PlaybackFailure.sourceUnavailable) {
      update(const ProbeVideoState(error: '视频无法播放，请重新读取或打开原帖。'));
      return;
    }
    _refreshUsed = true;
    try {
      final refreshed = await gateway.resolve(video.source, refresh: true);
      if (_closed || generation != _generation) return;
      if (refreshed is! ResolvedVideo) {
        throw const ContentAccessException(ContentAccessCode.sourceChanged);
      }
      await _start(refreshed, generation);
    } catch (_) {
      if (!_closed && generation == _generation) {
        update(const ProbeVideoState(error: '重新解析视频失败，请稍后重试。'));
      }
    }
  }

  void close() {
    _closed = true;
    _generation++;
    _playback?.dispose();
    _playback = null;
    destroy();
  }
}
