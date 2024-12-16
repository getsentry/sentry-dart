// coverage:ignore-file
// Note: Flutter Web test coverage isn't supported

import 'dart:async';
import 'dart:typed_data';

import '../../sentry_flutter.dart';
import '../native/native_app_start.dart';
import '../native/native_frames.dart';
import '../native/sentry_native_binding.dart';
import '../native/sentry_native_invoker.dart';
import '../replay/replay_config.dart';
import 'sentry_js_binding.dart';

abstract class SentryWebBinding {
  FutureOr<void> init();
  FutureOr<void> close();
}

class SentryWeb with SentryNativeSafeInvoker implements SentryNativeBinding {
  SentryWeb(this._binding, this._options);

  final SentryJsBinding _binding;
  final SentryFlutterOptions _options;

  @override
  FutureOr<void> init(Hub hub) {
    print('trying to init');
    tryCatchSync('init', () {
      final Map<String, dynamic> jsOptions = {
        'dsn': _options.dsn,
        'debug': _options.debug,
        'environment': _options.environment,
        'release': _options.release,
        'dist': _options.dist,
        'sampleRate': _options.sampleRate,
        'attachStacktrace': _options.attachStacktrace,
        'maxBreadcrumbs': _options.maxBreadcrumbs,
        // using defaultIntegrations ensures that we can control which integrations are added
        'defaultIntegrations': <String>[],
      };
      _binding.init(jsOptions);
    });
  }

  @override
  FutureOr<void> close() {
    tryCatchSync('close', () {
      _binding.close();
    });
  }

  @override
  FutureOr<void> addBreadcrumb(Breadcrumb breadcrumb) {
    throw UnsupportedError(
        "$SentryWeb.addBreadcrumb() not supported on this platform");
  }

  @override
  FutureOr<void> beginNativeFrames() {
    throw UnsupportedError(
        "$SentryWeb.beginNativeFrames() not supported on this platform");
  }

  @override
  FutureOr<void> captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException) {
    throw UnsupportedError(
        "$SentryWeb.captureEnvelope() not supported on this platform");
  }

  @override
  FutureOr<SentryId> captureReplay(bool isCrash) {
    throw UnsupportedError(
        "$SentryWeb.captureReplay() not supported on this platform");
  }

  @override
  FutureOr<void> clearBreadcrumbs() {
    throw UnsupportedError(
        "$SentryWeb.clearBreadcrumbs() not supported on this platform");
  }

  @override
  FutureOr<Map<String, dynamic>?> collectProfile(
      SentryId traceId, int startTimeNs, int endTimeNs) {
    throw UnsupportedError(
        "$SentryWeb.collectProfile() not supported on this platform");
  }

  @override
  FutureOr<void> discardProfiler(SentryId traceId) {
    throw UnsupportedError(
        "$SentryWeb.discardProfiler() not supported on this platform");
  }

  @override
  FutureOr<int?> displayRefreshRate() {
    throw UnsupportedError(
        "$SentryWeb.displayRefreshRate() not supported on this platform");
  }

  @override
  FutureOr<NativeFrames?> endNativeFrames(SentryId id) {
    throw UnsupportedError(
        "$SentryWeb.endNativeFrames() not supported on this platform");
  }

  @override
  FutureOr<NativeAppStart?> fetchNativeAppStart() {
    throw UnsupportedError(
        "$SentryWeb.fetchNativeAppStart() not supported on this platform");
  }

  @override
  FutureOr<Map<String, dynamic>?> loadContexts() {
    throw UnsupportedError(
        "$SentryWeb.loadContexts() not supported on this platform");
  }

  @override
  FutureOr<List<DebugImage>?> loadDebugImages(SentryStackTrace stackTrace) {
    throw UnsupportedError(
        "$SentryWeb.loadDebugImages() not supported on this platform");
  }

  @override
  FutureOr<void> nativeCrash() {
    throw UnsupportedError(
        "$SentryWeb.nativeCrash() not supported on this platform");
  }

  @override
  FutureOr<void> pauseAppHangTracking() {
    throw UnsupportedError(
        "$SentryWeb.pauseAppHangTracking() not supported on this platform");
  }

  @override
  FutureOr<void> removeContexts(String key) {
    throw UnsupportedError(
        "$SentryWeb.removeContexts() not supported on this platform");
  }

  @override
  FutureOr<void> removeExtra(String key) {
    throw UnsupportedError(
        "$SentryWeb.removeExtra() not supported on this platform");
  }

  @override
  FutureOr<void> removeTag(String key) {
    throw UnsupportedError(
        "$SentryWeb.removeTag() not supported on this platform");
  }

  @override
  FutureOr<void> resumeAppHangTracking() {
    throw UnsupportedError(
        "$SentryWeb.resumeAppHangTracking() not supported on this platform");
  }

  @override
  FutureOr<void> setContexts(String key, value) {
    throw UnsupportedError(
        "$SentryWeb.setContexts() not supported on this platform");
  }

  @override
  FutureOr<void> setExtra(String key, value) {
    throw UnsupportedError(
        "$SentryWeb.setExtra() not supported on this platform");
  }

  @override
  FutureOr<void> setReplayConfig(ReplayConfig config) {
    throw UnsupportedError(
        "$SentryWeb.setReplayConfig() not supported on this platform");
  }

  @override
  FutureOr<void> setTag(String key, String value) {
    throw UnsupportedError(
        "$SentryWeb.setTag() not supported on this platform");
  }

  @override
  FutureOr<void> setUser(SentryUser? user) {
    throw UnsupportedError(
        "$SentryWeb.setUser() not supported on this platform");
  }

  @override
  int? startProfiler(SentryId traceId) {
    throw UnsupportedError(
        "$SentryWeb.startProfiler() not supported on this platform");
  }

  @override
  bool get supportsCaptureEnvelope => false;

  @override
  bool get supportsLoadContexts => false;

  @override
  bool get supportsReplay => false;

  @override
  SentryFlutterOptions get options => _options;
}
