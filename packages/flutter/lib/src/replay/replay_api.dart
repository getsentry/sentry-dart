import 'dart:async';

import 'package:meta/meta.dart';

import '../native/sentry_native_binding.dart';
import '../utils/internal_logger.dart';

/// Controls Session Replay recording.
///
/// Only Android and iOS support Session Replay. On every other platform these
/// methods are no-ops.
abstract interface class SentryReplay {
  /// Starts a new replay session.
  ///
  /// This explicit start bypasses session sampling. It does nothing when a
  /// replay is already active.
  Future<void> start();

  /// Starts Replay in buffer mode.
  ///
  /// This explicit start bypasses session sampling. The rolling buffer is sent
  /// by [flush] or when an error is selected by the configured error sample
  /// rate, then recording continues in session mode.
  Future<void> startBuffering();

  /// Pauses the active replay until [resume] is called.
  Future<void> pause();

  /// Resumes a replay paused with [pause].
  Future<void> resume();

  /// Stops the active replay.
  ///
  /// A subsequent [start] or [startBuffering] creates a new replay.
  Future<void> stop();

  /// Sends the current replay data and continues in session mode.
  ///
  /// If Replay is inactive, this starts a new replay session.
  Future<void> flush();
}

@internal
SentryReplay createSentryReplay(
  SentryNativeBinding? Function() nativeProvider,
) => _SentryReplay(nativeProvider);

final class _SentryReplay implements SentryReplay {
  _SentryReplay(this._nativeProvider);

  final SentryNativeBinding? Function() _nativeProvider;

  Future<void> _invoke(
    String operation,
    FutureOr<void> Function(SentryNativeBinding native) callback,
  ) async {
    final native = _nativeProvider();
    if (native == null) {
      internalLogger.debug(
        'SentryFlutter.replay.$operation() was ignored because the native '
        'integration is unavailable. Make sure SentryFlutter.init() ran first.',
      );
      return;
    }
    if (!native.supportsReplay) {
      internalLogger.debug(
        'SentryFlutter.replay.$operation() was ignored because Session Replay '
        'is not supported on this platform.',
      );
      return;
    }
    await callback(native);
  }

  @override
  Future<void> start() => _invoke('start', (native) => native.startReplay());

  @override
  Future<void> startBuffering() =>
      _invoke('startBuffering', (native) => native.startReplayBuffering());

  @override
  Future<void> pause() => _invoke('pause', (native) => native.pauseReplay());

  @override
  Future<void> resume() => _invoke('resume', (native) => native.resumeReplay());

  @override
  Future<void> stop() => _invoke('stop', (native) => native.stopReplay());

  @override
  Future<void> flush() => _invoke('flush', (native) => native.flushReplay());
}
