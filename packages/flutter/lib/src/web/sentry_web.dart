import 'dart:async';
import 'dart:typed_data';

import 'package:collection/collection.dart';
// ignore: implementation_imports
import 'package:sentry/src/sentry_item_type.dart';

import '../../sentry_flutter.dart';
import '../native/native_app_start.dart';
import '../native/sentry_native_binding.dart';
import '../native/sentry_native_invoker.dart';
import '../replay/replay_config.dart';
import 'sentry_js_binding.dart';

class SentryWeb with SentryNativeSafeInvoker implements SentryNativeBinding {
  SentryWeb(this._binding, this._options);

  final SentryJsBinding _binding;
  final SentryFlutterOptions _options;

  void _log(String message) {
    _options.log(SentryLevel.info, logger: '$SentryWeb', message);
  }

  void _logNotSupported(String operation) =>
      _log('$operation is not supported');

  @override
  FutureOr<void> init(Hub hub) {
    tryCatchSync('init', () {
      final Map<String, dynamic> jsOptions = {
        'dsn': _options.dsn,
        'debug': _options.debug,
        'environment': _options.environment,
        'release': _options.release,
        'dist': _options.dist,
        'sampleRate': _options.sampleRate ?? 1,
        'tracesSampleRate': 0,
        'attachStacktrace': _options.attachStacktrace,
        'maxBreadcrumbs': _options.maxBreadcrumbs,
        // using defaultIntegrations ensures that we can control which integrations are added
        'defaultIntegrations': <String>{
          SentryJsIntegrationName.globalHandlers,
          SentryJsIntegrationName.dedupe
        },
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
  FutureOr<void> captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException) {
    _logNotSupported('capture raw envelope data');
  }

  @override
  FutureOr<void> captureStructuredEnvelope(SentryEnvelope envelope) =>
      tryCatchAsync('captureStructuredEnvelope', () async {
        final List<dynamic> envelopeItems = [];

        for (final item in envelope.items) {
          try {
            final dataFuture = item.dataFactory();
            final data = dataFuture is Future ? await dataFuture : dataFuture;

            // Only attachments should be filtered according to
            // SentryOptions.maxAttachmentSize
            if (item.header.type == SentryItemType.attachment &&
                data.length > options.maxAttachmentSize) {
              continue;
            }

            envelopeItems.add([
              await item.header.toJson(data.length),
              data,
            ]);
          } catch (_) {
            if (options.automatedTestMode) {
              rethrow;
            }
            // Skip throwing envelope item data closure.
            continue;
          }
        }

        final jsEnvelope = [envelope.header.toJson(), envelopeItems];

        _binding.captureEnvelope(jsEnvelope);
      });

  @override
  FutureOr<void> startSession({bool ignoreDuration = false}) {
    tryCatchSync('startSession', () {
      _binding.startSession();
    });
  }

  @override
  FutureOr<Map<dynamic, dynamic>?> getSession() =>
      tryCatchSync('getSession', () {
        return _binding.getSession();
      });

  @override
  FutureOr<void> updateSession({int? errors, String? status}) {
    tryCatchSync('updateSession', () {
      _binding.updateSession(errors: errors, status: status);
    });
  }

  @override
  FutureOr<void> captureSession() {
    tryCatchSync('captureSession', () {
      _binding.captureSession();
    });
  }

  @override
  FutureOr<SentryId> captureReplay() {
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
    final debugIdMap = _binding.getFilenameToDebugIdMap();
    if (debugIdMap == null || debugIdMap.isEmpty) {
      _log('Could not find debug id in js source file.');
      return null;
    }

    final frame = stackTrace.frames.firstWhereOrNull((frame) {
      return debugIdMap.containsKey(frame.absPath) ||
          debugIdMap.containsKey(frame.fileName);
    });
    if (frame == null) {
      _log('Could not find any frame with a matching debug id.');
      return null;
    }

    final codeFile = frame.absPath ?? frame.fileName;
    final debugId = debugIdMap[codeFile];
    if (debugId != null) {
      return [
        DebugImage(
          debugId: debugId,
          type: 'sourcemap',
          codeFile: codeFile,
        ),
      ];
    }

    _log('Could not match any frame against the debug id map.');
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
  FutureOr<void> setTrace(SentryId traceId, SpanId spanId) {
    _logNotSupported('setting trace');
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
  SentryId? get replayId => null;

  @override
  bool get supportsTraceSync => false;

  @override
  SentryFlutterOptions get options => _options;
}
