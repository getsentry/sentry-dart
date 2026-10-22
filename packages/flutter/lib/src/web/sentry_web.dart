// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

// ignore: implementation_imports
import 'package:sentry/src/envelope/sentry_item_type.dart';
// ignore: implementation_imports
import 'package:sentry/src/utils/iterable_utils.dart';

import '../../sentry_flutter.dart';
import 'replay/web_replay_event_processor.dart';
import '../native/native_app_start.dart';
import '../native/sentry_native_binding.dart';
import '../native/sentry_native_invoker.dart';
import '../native/utils/data_normalizer.dart';
import '../utils/internal_logger.dart';
import '../replay/replay_config.dart';
import '../replay/scheduled_recorder_config.dart';
import '../screen_capture/screenshot_support.dart';
import 'replay/real_web_replay_canvas_bridge.dart';
import 'replay/sentry_web_replay_recorder.dart';
import 'replay/web_replay_canvas_bridge.dart';
import 'replay/web_replay_capture_scale.dart';
import 'sentry_js_binding.dart';

class SentryWeb with SentryNativeSafeInvoker implements SentryNativeBinding {
  SentryWeb(
    this._binding,
    this._options, {
    @visibleForTesting
    WebReplayCanvasBridge Function(WebReplayCanvasIntegration)?
    createReplayCanvasBridge,
  }) : _createReplayCanvasBridge =
           createReplayCanvasBridge ?? RealWebReplayCanvasBridge.new;

  final SentryJsBinding _binding;
  final SentryFlutterOptions _options;
  final WebReplayCanvasBridge Function(WebReplayCanvasIntegration)
  _createReplayCanvasBridge;
  SentryWebReplayRecorder? _replayRecorder;
  WebReplayEventProcessor? _replayEventProcessor;

  static const _piiKeyPatterns = [
    'forwarded',
    '-ip',
    'remote-',
    'via',
    '-user',
  ];

  void _log(String message) {
    internalLogger.info('$SentryWeb: $message');
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
        // Preserve the JS v10 PII baseline until Flutter exposes dataCollection.
        // https://github.com/getsentry/sentry-javascript/blob/11.0.0/MIGRATION.md#senddefaultpii-is-replaced-by-datacollection
        'dataCollection': {
          'userInfo': _options.sendDefaultPii,
          if (!_options.sendDefaultPii) ...{
            'cookies': false,
            'httpHeaders': {
              'request': {'deny': _piiKeyPatterns},
              'response': {'deny': _piiKeyPatterns},
            },
            'httpBodies': <String>[],
            'urlQueryParams': {'deny': _piiKeyPatterns},
            'graphQL': {'document': false, 'variables': false},
            'genAI': {'inputs': false, 'outputs': false},
            'databaseQueryData': false,
            'queues': false,
          },
        },
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
        final processor = WebReplayEventProcessor(_binding);
        _options.addEventProcessor(processor);
        _replayEventProcessor = processor;
        _replayRecorder = SentryWebReplayRecorder(
          _options,
          bridge: _createReplayCanvasBridge(
            canvasIntegration as WebReplayCanvasIntegration,
          ),
          // Also non-null while the replay buffers for onErrorSampleRate:
          // see SentryJsBinding.getReplayId.
          isRecording: () => replayId != null,
        );
      }
    });
  }

  @override
  FutureOr<void> close() {
    final processor = _replayEventProcessor;
    if (processor != null) {
      _options.removeEventProcessor(processor);
      _replayEventProcessor = null;
    }
    // Queued, so replay calls still in flight finish before the JS SDK closes.
    // Only flushReplay and stopReplay await the JS SDK, which uploads the
    // replay there with bounded retries (sendReplay in
    // @sentry-internal/replay 11.0.0).
    return _enqueueReplayCall('close', () async {
      final recorder = _replayRecorder;
      // Later replay calls see no recorder and do nothing.
      _replayRecorder = null;
      try {
        // Stopping waits for an in-flight capture, which could otherwise
        // snapshot into the JS SDK after it's closed. Stopped even if it
        // never started: a failed start() can leave the shadow canvas in
        // the DOM.
        if (recorder != null) {
          _replayRecorderStarted = false;
          await recorder.stop();
        }
      } finally {
        _binding.close();
      }
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
    tryCatchSync('addBreadcrumb', () {
      _binding.addBreadcrumb(jsBreadcrumb);
    });

    final replayBreadcrumb = _replayBreadcrumb(jsBreadcrumb);
    if (replayBreadcrumb != null) {
      tryCatchSync('addReplayBreadcrumb', () {
        _binding.addReplayBreadcrumb(replayBreadcrumb);
      });
    }
  }

  @override
  FutureOr<void> captureEnvelope(Uint8List envelopeData) {
    _logNotSupported('capture raw envelope data');
  }

  @override
  FutureOr<void> updateSessionForDroppedEventNonTerminating(bool unhandled) {
    _logNotSupported('update session for dropped non-terminating event');
  }

  @override
  FutureOr<void> captureStructuredEnvelope(SentryEnvelope envelope) =>
      tryCatchAsync('captureStructuredEnvelope', () async {
        final List<dynamic> envelopeItems = [];
        final List<Map<String, dynamic>> events = [];
        // Only the JS SDK's Replay needs the events (for afterSendEvent), so
        // don't decode every event without it.
        final collectEvents = supportsReplay;

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

            envelopeItems.add([await item.header.toJson(data.length), data]);

            if (collectEvents &&
                (item.header.type == SentryItemType.event ||
                    item.header.type == SentryItemType.transaction)) {
              events.add(jsonDecode(utf8.decode(data)) as Map<String, dynamic>);
            }
          } catch (_) {
            if (options.automatedTestMode) {
              rethrow;
            }
            // Skip throwing envelope item data closure.
            continue;
          }
        }

        final jsEnvelope = [envelope.header.toJson(), envelopeItems];

        _binding.captureEnvelope(jsEnvelope, events);
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
      "$SentryWeb.captureReplay() not supported on this platform",
    );
  }

  @override
  FutureOr<void> startReplay() =>
      _startReplay('startReplay', _binding.startReplay);

  @override
  FutureOr<void> startReplayBuffering() =>
      _startReplay('startReplayBuffering', _binding.startReplayBuffering);

  // The JS SDK can't pause a replay.
  @override
  FutureOr<void> pauseReplay() {
    _logNotSupported('pausing replay');
  }

  @override
  FutureOr<void> resumeReplay() {
    _logNotSupported('resuming replay');
  }

  @override
  FutureOr<void> stopReplay() =>
      _replayRecorderCall('stopReplay', (recorder) async {
        _replayStopped = true;
        try {
          // Stopping waits for an in-flight capture, which could otherwise
          // snapshot into the stopped replay.
          await _stopReplayRecorder(recorder);
        } finally {
          await _binding.stopReplay();
        }
      });

  // The JS SDK starts a new replay when flushing an inactive one, so the
  // recorder is started too.
  @override
  FutureOr<void> flushReplay() =>
      _startReplay('flushReplay', _binding.flushReplay);

  @override
  FutureOr<void> clearBreadcrumbs() {
    tryCatchSync('clearBreadcrumbs', () {
      _binding.clearBreadcrumbs();
    });
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
        DebugImage(debugId: debugId, type: 'sourcemap', codeFile: codeFile),
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
    tryCatchSync('removeContexts', () {
      _binding.removeContext(key);
    });
  }

  @override
  FutureOr<void> removeExtra(String key) {
    tryCatchSync('removeExtra', () {
      _binding.removeExtra(key);
    });
  }

  @override
  FutureOr<void> removeTag(String key) {
    tryCatchSync('removeTag', () {
      _binding.removeTag(key);
    });
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
    tryCatchSync('setContexts', () {
      _binding.setContext(key, normalize(value));
    });
  }

  @override
  FutureOr<void> setExtra(String key, value) {
    tryCatchSync('setExtra', () {
      _binding.setExtra(key, normalize(value));
    });
  }

  bool _replayRecorderStarted = false;
  // Set by stopReplay so that config changes (e.g. a window resize) don't
  // restart recording until the replay is started again.
  bool _replayStopped = false;

  // Replay calls (start, stop, flush, config changes, close) run one at a
  // time, in call order. Each awaits the JS SDK and the recorder, and letting
  // them interleave raced, e.g. a stop landing while a start still awaited
  // the JS SDK. Queued, each starts from the state the previous one left.
  Future<void> _replayCalls = Future.value();

  Future<void> _enqueueReplayCall(
    String nativeMethodName,
    Future<void> Function() call,
  ) {
    final result = _replayCalls.then(
      (_) => tryCatchAsync(nativeMethodName, call),
    );
    // A failure reaches only this call's caller; later calls still run.
    _replayCalls = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  FutureOr<void> _replayRecorderCall(
    String nativeMethodName,
    Future<void> Function(SentryWebReplayRecorder recorder) call,
  ) {
    // Replay is disabled: don't call the JS SDK.
    if (_replayRecorder == null) return null;

    return _enqueueReplayCall(nativeMethodName, () async {
      // Null once close() ran.
      final recorder = _replayRecorder;
      if (recorder != null) await call(recorder);
    });
  }

  @override
  FutureOr<void> setReplayConfig(ReplayConfig config) =>
      _replayRecorderCall('setReplayConfig', (recorder) async {
        // Independent of config.width/height, which already have
        // SentryReplayQuality.resolutionScalingFactor baked in by the shared
        // ReplayIntegration that calls this -- web maps the quality to its own
        // factor on the real window size instead (see webReplayCaptureScale).
        final scale = webReplayCaptureScale(_options.replay.quality);
        await recorder.onConfigurationChanged(
          ScheduledScreenshotRecorderConfig(
            width: scale * config.windowWidth,
            height: scale * config.windowHeight,
            frameRate: config.frameRate,
          ),
        );
        if (!_replayStopped) {
          await _startReplayRecorder(recorder);
        }
      });

  FutureOr<void> _startReplay(
    String nativeMethodName,
    FutureOr<void> Function() startJsReplay,
  ) => _replayRecorderCall(nativeMethodName, (recorder) async {
    await startJsReplay();
    _replayStopped = false;
    await _startReplayRecorder(recorder);
  });

  Future<void> _startReplayRecorder(SentryWebReplayRecorder recorder) async {
    if (_replayRecorderStarted) return;
    await recorder.start();
    // Only after start() succeeds, so a failed start is retried next time.
    _replayRecorderStarted = true;
  }

  Future<void> _stopReplayRecorder(SentryWebReplayRecorder recorder) async {
    if (!_replayRecorderStarted) return;
    // Cleared first, so a failed stop doesn't block later starts.
    _replayRecorderStarted = false;
    await recorder.stop();
  }

  @override
  FutureOr<void> setTag(String key, String value) {
    tryCatchSync('setTag', () {
      _binding.setTag(key, value);
    });
  }

  @override
  FutureOr<void> setUser(SentryUser? user) {
    tryCatchSync('setUser', () {
      _binding.setUser(user == null ? null : normalizeMap(user.toJson()));
    });
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
  bool get supportsCaptureEnvelope => true;

  @override
  bool get supportsLoadContexts => false;

  // Requires a sample rate, unlike on mobile: init only loads the JS Replay
  // bundle then, so apps not using replay don't download it. A manual
  // SentryFlutter.replay.start() therefore needs a rate above 0 on web (see
  // SentryReplay).
  @override
  bool get supportsReplay =>
      _options.replay.isEnabled && _options.isScreenshotSupported;

  @override
  SentryId? get replayId {
    final replayId = _binding.getReplayId(onlyIfSampled: true);
    return replayId == null ? null : SentryId.fromId(replayId);
  }

  // Nothing puts the JS replay's ID on the Dart scope, so the scope can't
  // tell a buffering replay from a session one.
  @override
  bool? get isReplayBuffering => _binding.isReplayBuffering();

  @override
  String? get proguardUuid => null;

  @override
  bool get supportsTraceSync => false;

  @override
  SentryFlutterOptions get options => _options;

  // The JS Replay records every breadcrumb added through the JS SDK, except
  // the ones its normalizeBreadcrumb drops (@sentry-internal/replay 11.0.0):
  // uncategorized ones, `fetch`, `xhr` and `ui.*` (it records its own network
  // requests and DOM clicks) and `sentry.event`/`sentry.transaction`. This
  // returns a replay-only copy of the dropped Dart ones, recategorized so the
  // replay keeps them. Each Dart breadcrumb therefore reaches the replay once,
  // and the labeled `ui.*` event breadcrumb never does.
  Map<String, dynamic>? _replayBreadcrumb(Map<String, dynamic> breadcrumb) {
    final category = breadcrumb['category'];
    if (category is! String || category.isEmpty) {
      return {...breadcrumb, 'category': 'default'};
    }

    if (category == 'fetch' ||
        category == 'xhr' ||
        category.startsWith('ui.')) {
      final message = breadcrumb['message'] ?? _viewName(breadcrumb['data']);
      return {
        ...breadcrumb,
        'message': ?message,
        'category': 'flutter.$category',
        'data': ?_withoutLabels(breadcrumb['data']),
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

  // Copies breadcrumb data without the tapped widget's label or the labels in
  // its touch path: they're text the replay video masks. The event breadcrumb
  // keeps them, gated by `sendDefaultPii` where they're collected.
  Map<String, dynamic>? _withoutLabels(Object? data) {
    if (data is! Map) return null;
    final result = Map<String, dynamic>.from(data)..remove('label');
    final path = result['path'];
    if (path is List) {
      result['path'] = [
        for (final node in path)
          node is Map
              ? (Map<String, dynamic>.from(node)..remove('label'))
              : node,
      ];
    }
    return result;
  }
}
