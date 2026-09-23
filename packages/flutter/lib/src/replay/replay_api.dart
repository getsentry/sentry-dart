import 'dart:async';

import 'package:meta/meta.dart';

import '../native/sentry_native_binding.dart';
import '../utils/internal_logger.dart';

/// Controls Session Replay recording.
///
/// Access via `SentryFlutter.replay`.
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
final class DefaultSentryReplay implements SentryReplay {
  DefaultSentryReplay(this._nativeProvider);

  final SentryNativeBinding? Function() _nativeProvider;

  /// The binding to control, or null when there is nothing to control because
  /// the SDK isn't initialized or the platform has no Session Replay.
  SentryNativeBinding? get _native {
    final native = _nativeProvider();
    if (native == null) {
      internalLogger.debug(
        'SentryFlutter.replay was used before SentryFlutter.init(), so the '
        'native integration is unavailable.',
      );
      return null;
    }
    if (!native.supportsReplay) {
      internalLogger.debug('Session Replay is not supported on this platform.');
      return null;
    }
    return native;
  }

  @override
  Future<void> start() async => _native?.startReplay();

  @override
  Future<void> startBuffering() async => _native?.startReplayBuffering();

  @override
  Future<void> pause() async => _native?.pauseReplay();

  @override
  Future<void> resume() async => _native?.resumeReplay();

  @override
  Future<void> stop() async => _native?.stopReplay();

  @override
  Future<void> flush() async => _native?.flushReplay();
}
