// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'dart:ui';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../frame_callback_handler.dart';
import '../native/sentry_native_binding.dart';
import '../utils/internal_logger.dart';
import 'app_start_emitter.dart';
import 'app_start_info.dart';
import 'native_app_start_parser.dart';
import 'static_app_start_emitter.dart';
import 'stream_app_start_emitter.dart';

/// Feeds native app start data into the lifecycle-specific app start emitter
/// once the first frame timing is available.
class NativeAppStartIntegration extends Integration<SentryFlutterOptions> {
  NativeAppStartIntegration(
    this._frameCallbackHandler,
    this._native,
  );

  @internal
  static const integrationName = 'NativeAppStart';

  final FrameCallbackHandler _frameCallbackHandler;
  final SentryNativeBinding _native;

  TimingsCallback? _timingsCallback;
  bool _allowProcessing = true;

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    if (!options.isTracingEnabled()) {
      internalLogger.info(
          'Skipping $integrationName integration because tracing is disabled.');
      return;
    }

    final AppStartEmitter emitter = switch (options.traceLifecycle) {
      SentryTraceLifecycle.static => _createStaticEmitter(
          hub: hub,
          options: options,
        ),
      SentryTraceLifecycle.stream => _createStreamEmitter(
          hub: hub,
          options: options,
        ),
    };

    void timingsCallback(List<FrameTiming> timings) async {
      if (!_allowProcessing) {
        return;
      }
      // Native app start has a single feeder today. Guard before the async
      // native fetch so duplicate frame timings cannot start duplicate work.
      _allowProcessing = false;

      try {
        final appStartEnd = DateTime.fromMicrosecondsSinceEpoch(timings.first
            .timestampInMicroseconds(FramePhase.rasterFinishWallTime));

        final nativeAppStart = await _native.fetchNativeAppStart();
        final AppStartInfo? appStartInfo = nativeAppStart == null
            ? null
            : parseNativeAppStart(nativeAppStart, appStartEnd);
        if (appStartInfo == null) {
          emitter.cancel();
          return;
        }

        await emitter.emit(appStartInfo);
      } catch (exception, stackTrace) {
        internalLogger.error(
          'Error while capturing native app start',
          error: exception,
          stackTrace: stackTrace,
        );
        emitter.cancel();
        if (options.automatedTestMode) {
          rethrow;
        }
      } finally {
        _removeTimingsCallback();
      }
    }

    _timingsCallback = timingsCallback;
    _frameCallbackHandler.addTimingsCallback(timingsCallback);
    options.sdk.addIntegration(integrationName);
    if (options.enableStandaloneAppStartTracing) {
      options.sdk.addFeature(SentryFeatures.standaloneAppStartTracing);
    }
  }

  @override
  void close() {
    _allowProcessing = false;
    _removeTimingsCallback();
  }

  void _removeTimingsCallback() {
    final timingsCallback = _timingsCallback;
    if (timingsCallback != null) {
      _frameCallbackHandler.removeTimingsCallback(timingsCallback);
      _timingsCallback = null;
    }
  }

  StaticAppStartEmitter _createStaticEmitter({
    required Hub hub,
    required SentryFlutterOptions options,
  }) {
    final context = SentryTransactionContext(
      'root /',
      SentrySpanOperations.uiLoad,
      origin: SentryTraceOrigins.autoUiTimeToDisplay,
    );

    final timeToDisplayTracker = options.timeToDisplayTracker;
    timeToDisplayTracker.transactionId = context.spanId;

    return StaticAppStartEmitter(
      hub: hub,
      context: context,
      timeToDisplayTracker: timeToDisplayTracker,
      standalone: options.enableStandaloneAppStartTracing,
    );
  }

  StreamAppStartEmitter _createStreamEmitter({
    required Hub hub,
    required SentryFlutterOptions options,
  }) {
    final timeToDisplayTracker = options.timeToDisplayTrackerV2;
    timeToDisplayTracker.prepareAppStart();

    return StreamAppStartEmitter(
      hub: hub,
      timeToDisplayTracker: timeToDisplayTracker,
      standalone: options.enableStandaloneAppStartTracing,
    );
  }
}
