import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import '../../sentry_flutter.dart';
import '../native/native_app_start.dart';
import '../native/native_frames.dart';
import '../native/sentry_native_binding.dart';
import '../native/sentry_native_invoker.dart';
import '../replay/replay_config.dart';
import 'sentry_js_binding.dart';

class SentryWeb with SentryNativeSafeInvoker implements SentryNativeBinding {
  SentryWeb(this._binding, this._options);

  final SentryJsBinding _binding;
  final SentryFlutterOptions _options;

  void _logNotSupported(String operation) => options.logger(
      SentryLevel.debug, 'SentryWeb: $operation is not supported');

  @override
  FutureOr<void> init(Hub hub) {
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
        'defaultIntegrations': <dynamic>[],
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
    _logNotSupported('add breadcrumb');
  }

  @override
  FutureOr<void> beginNativeFrames() {
    _logNotSupported('begin native frames collection');
  }

  @override
  FutureOr<void> captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException) {
    _logNotSupported('capture envelope with raw data');
  }

  @override
  FutureOr<void> captureEnvelopeObject(SentryEnvelope envelope) async {
    final List<dynamic> envelopeItems = [];

    for (final item in envelope.items) {
      final originalObject = item.originalObject;
      final payload = await originalObject?.getPayload();
      if (payload is Uint8List) {
        final length = payload.length;
        envelopeItems.add([
          (await item.header.toJson(length)),
          payload,
        ]);
      } else {
        final length =
            payload != null ? utf8.encode(json.encode(payload)).length : 0;
        envelopeItems.add([(await item.header.toJson(length)), payload]);
      }

      // We use `sendEnvelope` where sessions are not managed in the JS SDK
      // so we have to do it manually
      if (originalObject is SentryEvent &&
          originalObject.exceptions?.isEmpty == false) {
        // todo: how to test this except manually checking?
        final session = _binding.getSession();
        if (session != null) {
          if (envelope.containsUnhandledException) {
            session.status = 'crashed'.toJS;
          }
          session.errors = originalObject.exceptions!.length.toJS;
          _binding.captureSession();
        }
      }
    }

    final jsEnvelope = [envelope.header.toJson(), envelopeItems];

    _binding.captureEnvelope(jsEnvelope);
  }

  String uint8ListToHexString(Uint8List uint8list) {
    var hex = "";
    for (var i in uint8list) {
      var x = i.toRadixString(16);
      if (x.length == 1) {
        x = "0$x";
      }
      hex += x;
    }
    return hex;
  }

  @override
  FutureOr<SentryId> captureReplay(bool isCrash) {
    throw UnsupportedError(
        "$SentryWeb.captureReplay() not supported on this platform");
  }

  @override
  FutureOr<void> clearBreadcrumbs() {
    _logNotSupported('clear breadcrumbs');
  }

  @override
  FutureOr<Map<String, dynamic>?> collectProfile(
      SentryId traceId, int startTimeNs, int endTimeNs) {
    _logNotSupported('collect profile');
    return null;
  }

  @override
  FutureOr<void> discardProfiler(SentryId traceId) {
    _logNotSupported('discard profiler');
  }

  @override
  FutureOr<int?> displayRefreshRate() {
    _logNotSupported('fetching display refresh rate');
    return null;
  }

  @override
  FutureOr<NativeFrames?> endNativeFrames(SentryId id) {
    _logNotSupported('end native frames collection');
    return null;
  }

  @override
  FutureOr<NativeAppStart?> fetchNativeAppStart() {
    _logNotSupported('fetch native app start');
    return null;
  }

  @override
  FutureOr<Map<String, dynamic>?> loadContexts() {
    _logNotSupported('load contexts');
    return null;
  }

  @override
  FutureOr<List<DebugImage>?> loadDebugImages(SentryStackTrace stackTrace) {
    _logNotSupported('loading debug images');
    return null;
  }

  @override
  FutureOr<void> nativeCrash() {
    _logNotSupported('native crash');
  }

  @override
  FutureOr<void> removeContexts(String key) {
    _logNotSupported('remove contexts');
  }

  @override
  FutureOr<void> removeExtra(String key) {
    _logNotSupported('remove extra');
  }

  @override
  FutureOr<void> removeTag(String key) {
    _logNotSupported('remove tag');
  }

  @override
  FutureOr<void> resumeAppHangTracking() {
    _logNotSupported('resume app hang tracking');
  }

  @override
  FutureOr<void> pauseAppHangTracking() {
    _logNotSupported('pause app hang tracking');
  }

  @override
  FutureOr<void> setContexts(String key, value) {
    _logNotSupported('set contexts');
  }

  @override
  FutureOr<void> setExtra(String key, value) {
    _logNotSupported('set extra');
  }

  @override
  FutureOr<void> setReplayConfig(ReplayConfig config) {
    _logNotSupported('setting replay config');
  }

  @override
  FutureOr<void> setTag(String key, String value) {
    _logNotSupported('set tag');
  }

  @override
  FutureOr<void> setUser(SentryUser? user) {
    _logNotSupported('set user');
  }

  @override
  int? startProfiler(SentryId traceId) {
    _logNotSupported('start profiler');
    return null;
  }

  @override
  bool get supportsCaptureEnvelope => true;

  @override
  bool get supportsLoadContexts => false;

  @override
  bool get supportsReplay => false;

  @override
  SentryFlutterOptions get options => _options;
}
