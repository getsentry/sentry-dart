import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../replay/replay_config.dart';
import '../sentry_native_channel.dart';
import 'cocoa_ffi.dart';
import 'cocoa_replay_recorder.dart';

@internal
class SentryNativeCocoa extends SentryNativeChannel {
  CocoaReplayRecorder? _replayRecorder;
  SentryId? _replayId;
  int _replayGeneration = 0;
  Hub? _hub;

  SentryNativeCocoa(super.options);

  @override
  bool get supportsReplay => options.platform.isIOS;

  @override
  SentryId? get replayId => _replayId;

  @override
  Future<void> init(Hub hub) async {
    _hub = hub;
    if (supportsReplay) {
      channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'captureReplayScreenshot':
            _replayRecorder ??= CocoaReplayRecorder(options);

            final replayIdArg = call.arguments['replayId'];
            final replayIsBuffering =
                call.arguments['replayIsBuffering'] as bool? ?? false;

            final replayId = replayIdArg == null
                ? null
                : SentryId.fromId(replayIdArg as String);

            _replayId = replayId;
            final scopeReplayId = replayIsBuffering ? null : replayId;
            // ignore: invalid_use_of_internal_member
            if (hub.scope.replayId != scopeReplayId) {
              hub.configureScope((s) {
                // ignore: invalid_use_of_internal_member
                s.replayId = scopeReplayId;
              });
            }

            return _replayRecorder!.captureScreenshot();
          default:
            throw UnimplementedError('Method ${call.method} not implemented');
        }
      });
    }

    return super.init(hub);
  }

  @override
  FutureOr<void> addBreadcrumb(
    Breadcrumb breadcrumb, {
    Map<String, dynamic>? networkRequestDetail,
    Map<String, dynamic>? networkResponseDetail,
  }) async {
    final ffi = await (_ffi ??= CocoaFfi.load(channel));
    if (ffi == null) {
      return super.addBreadcrumb(breadcrumb);
    }
    tryCatchSync(
      'addBreadcrumb',
      () => ffi.addBreadcrumb(normalizedBreadcrumbJson(breadcrumb)),
    );
  }

  /// Loaded lazily on first use rather than in [init], which does not run
  /// when `autoInitializeNativeSdk` is disabled. Shared across concurrent
  /// callers so the entry points are requested only once.
  Future<CocoaFfi?>? _ffi;

  @override
  FutureOr<SentryId> captureReplay() async {
    final replayId = await super.captureReplay();
    _replayId = replayId;
    return replayId;
  }

  @override
  Future<void> flushReplay() async {
    final generation = _replayGeneration;
    final value = await channel.invokeMethod<String>('flushReplay');
    // A stop invalidates promotion responses that are already in flight.
    if (generation != _replayGeneration) return;
    final replayId = value == null ? null : SentryId.fromId(value);
    _replayId = replayId == const SentryId.empty() ? null : replayId;
    // Synchronize promotion before returning, without waiting for a screenshot.
    await _hub?.configureScope((s) {
      // ignore: invalid_use_of_internal_member
      s.replayId = _replayId;
    });
  }

  @override
  Future<void> stopReplay() async {
    _replayGeneration++;
    try {
      await super.stopReplay();
    } finally {
      // iOS reports replay IDs only through the screenshot provider, which goes
      // quiet once recording stops. Android has `replayStopped` for this.
      _replayId = null;
      _hub?.configureScope((s) {
        // ignore: invalid_use_of_internal_member
        s.replayId = null;
      });
    }
  }

  @override
  FutureOr<void> setReplayConfig(ReplayConfig config) {
    // Note: unused on iOS.
  }
}
