// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';
import 'dart:typed_data';

// ignore: implementation_imports
import 'package:sentry/src/sentry_item_type.dart';
// ignore: implementation_imports
import 'package:sentry/src/utils/iterable_utils.dart';

import '../../sentry_flutter.dart';
import '../event_processor/web_replay_event_processor.dart';
import '../native/native_app_start.dart';
import '../native/sentry_native_binding.dart';
import '../native/sentry_native_invoker.dart';
import '../native/utils/data_normalizer.dart';
import '../replay/replay_config.dart';
import '../replay/scheduled_recorder_config.dart';
import '../screenshot/screenshot_support.dart';
import 'replay/real_web_replay_canvas_bridge.dart';
import 'replay/sentry_web_replay_recorder.dart';
import 'replay/web_replay_capture_scale.dart';
import 'sentry_js_binding.dart';

class SentryWeb with SentryNativeSafeInvoker implements SentryNativeBinding {
  SentryWeb(this._binding, this._options);

  final SentryJsBinding _binding;
  final SentryFlutterOptions _options;
  SentryWebReplayRecorder? _replayRecorder;

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
          SentryJsIntegrationName.dedupe,
          // Adds the User-Agent (and page URL) to JS-side events, incl. the
          // replay event, so Sentry can show the browser and OS.
          SentryJsIntegrationName.httpContext,
        },
      };
      Object? canvasIntegration;
      if (supportsReplay) {
        // Constructed (not just named) so we keep a reference to drive it
        // ourselves -- enableManualSnapshot means auto-sampling is off, so
        // nothing captures a frame unless SentryWebReplayRecorder tells this
        // specific integration instance to snapshot one.
        canvasIntegration = _binding.createManualReplayCanvasIntegration();
        jsOptions.addAll({
          'replaysSessionSampleRate': _options.replay.sessionSampleRate ?? 0,
          'replaysOnErrorSampleRate': _options.replay.onErrorSampleRate ?? 0,
          'integrations': <Object?>[
            SentryJsIntegrationName.replay,
            canvasIntegration,
          ],
        });
      }
      _binding.init(jsOptions);
      if (supportsReplay && canvasIntegration != null) {
        _options.addEventProcessor(WebReplayEventProcessor(_binding));
        _replayRecorder = SentryWebReplayRecorder(
          _options,
          bridge: RealWebReplayCanvasBridge(
              canvasIntegration as WebReplayCanvasIntegration),
        );
      }
    });
  }

  @override
  FutureOr<void> close() {
    tryCatchSync('close', () {
      unawaited(_replayRecorder?.stop());
      _binding.close();
    });
  }

  @override
  FutureOr<void> addBreadcrumb(Breadcrumb breadcrumb) {
    final jsBreadcrumb = {
      'timestamp': breadcrumb.timestamp.millisecondsSinceEpoch / 1000,
      if (breadcrumb.message != null) 'message': breadcrumb.message,
      if (breadcrumb.category != null) 'category': breadcrumb.category,
      if (breadcrumb.data?.isNotEmpty ?? false)
        'data': normalizeMap(breadcrumb.data),
      if (breadcrumb.level != null) 'level': breadcrumb.level!.name,
      if (breadcrumb.type != null) 'type': breadcrumb.type,
    };
    _binding.addBreadcrumb(jsBreadcrumb);

    final replayBreadcrumb = _replayBreadcrumb(jsBreadcrumb);
    if (replayBreadcrumb != null) {
      _binding.addReplayBreadcrumb(replayBreadcrumb);
    }
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
    _binding.clearBreadcrumbs();
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

    final frame = stackTrace.frames.firstWhereOrNull(
      (frame) =>
          debugIdMap.containsKey(frame.absPath) ||
          debugIdMap.containsKey(frame.fileName),
    );
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
    _binding.removeContext(key);
  }

  @override
  FutureOr<void> removeExtra(String key) {
    _binding.removeExtra(key);
  }

  @override
  FutureOr<void> removeTag(String key) {
    _binding.removeTag(key);
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
    _binding.setContext(key, normalize(value));
  }

  @override
  FutureOr<void> setExtra(String key, value) {
    _binding.setExtra(key, normalize(value));
  }

  bool _replayRecorderStarted = false;

  @override
  FutureOr<void> setReplayConfig(ReplayConfig config) {
    final recorder = _replayRecorder;
    if (recorder == null) return null;

    return tryCatchAsync('setReplayConfig', () async {
      // Independent of config.width/height, which already have
      // SentryReplayQuality.resolutionScalingFactor baked in by the shared
      // ReplayIntegration that calls this -- web maps the quality to its own
      // factor on the real window size instead (see webReplayCaptureScale).
      final scale = webReplayCaptureScale(_options.replay.quality);
      await recorder.onConfigurationChanged(ScheduledScreenshotRecorderConfig(
        width: scale * config.windowWidth,
        height: scale * config.windowHeight,
        frameRate: config.frameRate,
      ));
      if (!_replayRecorderStarted) {
        _replayRecorderStarted = true;
        await recorder.start();
      }
    });
  }

  @override
  FutureOr<void> setTag(String key, String value) {
    _binding.setTag(key, value);
  }

  @override
  FutureOr<void> setUser(SentryUser? user) {
    _binding.setUser(user == null ? null : normalizeMap(user.toJson()));
  }

  @override
  FutureOr<void> setTrace(SentryId traceId, SpanId spanId) {
    _logNotSupported('setting trace');
  }

  @override
  FutureOr<void> registerTraceId(SentryId traceId) {
    // No-op. Replay trace ID registration is currently Android-only.
  }

  @override
  FutureOr<void> registerSegmentName(String segmentName) {
    // No-op. Replay segment name registration is currently Android-only.
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
  bool get supportsReplay =>
      _options.replay.isEnabled && _options.isScreenshotSupported;

  @override
  SentryId? get replayId {
    final replayId = _binding.getReplayId(onlyIfSampled: true);
    return replayId == null ? null : SentryId.fromId(replayId);
  }

  @override
  bool get supportsTraceSync => false;

  @override
  SentryFlutterOptions get options => _options;

  Map<String, dynamic>? _replayBreadcrumb(Map<String, dynamic> breadcrumb) {
    final category = breadcrumb['category'];
    if (category is! String || category.isEmpty) {
      return {
        ...breadcrumb,
        'category': 'default',
      };
    }

    if (category == 'fetch' ||
        category == 'xhr' ||
        category.startsWith('ui.')) {
      final message = breadcrumb['message'] ?? _viewName(breadcrumb['data']);
      return {
        ...breadcrumb,
        if (message != null) 'message': message,
        'category': 'flutter.$category',
      };
    }

    return null;
  }

  // Names where the user interacted, for replay breadcrumbs that have no
  // message. Deliberately not the `label`: it's text the replay video masks.
  String? _viewName(Object? data) {
    if (data is! Map) return null;
    final name = data['view.id'] ?? data['view.class'];
    return name is String && name.isNotEmpty ? name : null;
  }
}
