import 'package:better_player_plus/better_player_plus.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/resolved_content.dart';

enum PlaybackFailure { sourceUnavailable, other }

abstract interface class ProbePlayback {
  Future<void> initialize(
    ResolvedVideo video,
    void Function(PlaybackFailure) onFailure,
  );
  Widget buildView();
  void dispose();
}

/// Uses QuaX's existing player dependency, with a single owner and no disk cache.
class BetterPlayerProbePlayback implements ProbePlayback {
  BetterPlayerController? _controller;
  bool _disposed = false;
  @override
  Future<void> initialize(
    ResolvedVideo video,
    void Function(PlaybackFailure) onFailure,
  ) async {
    final controller = BetterPlayerController(
      BetterPlayerConfiguration(
        aspectRatio: video.aspectRatio,
        autoPlay: true,
        autoDispose: false,
        handleLifecycle: true,
        allowedScreenSleep: false,
      ),
    );
    _controller = controller;
    controller.addEventsListener((event) {
      if (_disposed ||
          event.betterPlayerEventType != BetterPlayerEventType.exception) {
        return;
      }
      final description = event.parameters?['exception']?.toString() ?? '';
      final sourceFailure = RegExp(
        r'\b(401|403|404|410)\b|HttpDataSource|Source error',
        caseSensitive: false,
      ).hasMatch(description);
      onFailure(
        sourceFailure
            ? PlaybackFailure.sourceUnavailable
            : PlaybackFailure.other,
      );
    });
    await controller.setupDataSource(
      BetterPlayerDataSource.network(
        video.variants.first.uri.toString(),
        cacheConfiguration: const BetterPlayerCacheConfiguration(
          useCache: false,
        ),
      ),
    );
  }

  @override
  Widget buildView() => _controller == null
      ? const SizedBox.shrink()
      : BetterPlayer(controller: _controller!);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _controller?.dispose(forceDispose: true);
    _controller = null;
  }
}
