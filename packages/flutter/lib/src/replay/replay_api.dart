import 'dart:async';

import 'package:meta/meta.dart';

import '../native/sentry_native_binding.dart';
import '../utils/internal_logger.dart';

/// Controls Session Replay recording.
///
/// Access via `SentryFlutter.replay`.
///
/// Only Android, iOS and Web support Session Replay. On every other platform
/// these methods are no-ops.
///
/// On Web, these methods also need the experimental
/// `options.replay.enableWebReplay` flag and Replay enabled through
/// `options.replay.sessionSampleRate` or `options.replay.onErrorSampleRate`
/// (any rate above 0): the Replay JavaScript bundle is only loaded then, so
/// apps that don't use Replay don't download it.
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
  ///
  /// A no-op on Web, where the JavaScript SDK can't pause a replay.
  Future<void> pause();

  /// Resumes a replay paused with [pause].
  ///
  /// A no-op on Web, see [pause].
  Future<void> resume();

  /// Stops recording touch positions until [resumeTouchTracking] is called.
  ///
  /// Use this on screens where tap positions could reveal sensitive input,
  /// such as a custom PIN pad, even when the content is masked. Only touch
  /// positions stop: screenshots and breadcrumbs are still recorded.
  ///
  /// This is independent of [pause]: [resume] does not resume touch tracking,
  /// and [resumeTouchTracking] does not record touches while the replay is
  /// paused. Touch tracking stays paused across new replays, [stop] and
  /// [start] until [resumeTouchTracking] is called. It can be called before a
  /// replay starts.
  ///
  /// A no-op on Web, where the JavaScript SDK can't pause touch tracking.
  Future<void> pauseTouchTracking();

  /// Resumes recording touch positions paused with [pauseTouchTracking].
  ///
  /// A no-op on Web, see [pauseTouchTracking].
  Future<void> resumeTouchTracking();

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
  Future<void> pauseTouchTracking() async =>
      _native?.pauseReplayTouchTracking();

  @override
  Future<void> resumeTouchTracking() async =>
      _native?.resumeReplayTouchTracking();

  @override
  Future<void> stop() async => _native?.stopReplay();

  @override
  Future<void> flush() async => _native?.flushReplay();
}
