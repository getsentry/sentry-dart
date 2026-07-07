// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'dart:ui';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../frame_callback_handler.dart';
import '../native/sentry_native_binding.dart';
import '../utils/internal_logger.dart';
import 'app_start_info.dart';
import 'native_app_start_parser.dart';
import 'standalone_app_start_emitter.dart';
import 'static_app_start_span_writer.dart';
import 'static_standalone_app_start_emitter.dart';
import 'stream_app_start_span_writer.dart';
import 'stream_standalone_app_start_emitter.dart';

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

    final _NativeAppStartHandler handler = switch (options.traceLifecycle) {
      SentryTraceLifecycle.static => _createStaticHandler(
          hub: hub,
          options: options,
        ),
      SentryTraceLifecycle.stream => _createStreamHandler(
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
          handler.cancel();
          return;
        }

        await handler.track(appStartInfo);
      } catch (exception, stackTrace) {
        internalLogger.error(
          'Error while capturing native app start',
          error: exception,
          stackTrace: stackTrace,
        );
        handler.cancel();
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

  _NativeAppStartHandler _createStaticHandler({
    required Hub hub,
    required SentryFlutterOptions options,
  }) {
    final timeToDisplayTracker = options.timeToDisplayTracker;
    timeToDisplayTracker.prepareAppStart();
    final staticWriter = StaticAppStartSpanWriter(hub: hub);
    final standaloneEmitter = options.enableStandaloneAppStartTracing
        ? StaticStandaloneAppStartEmitter(
            hub: hub,
            writer: staticWriter,
          )
        : null;

    return _NativeAppStartHandler(
      track: (appStartInfo) async {
        // Start TTID/TTFD tracking before awaiting the standalone capture: the
        // ui.load root's autoFinishAfter timer is already running and the
        // capture can block on transport. Tracking first attaches the TTID
        // child, so the root cannot auto-finish childless (and be dropped)
        // while the standalone transaction is being sent.
        final displayTracking = timeToDisplayTracker.trackAppStart(
          startTimestamp: appStartInfo.start,
          ttidEndTimestamp: appStartInfo.end,
          attachAppStart: standaloneEmitter == null
              ? (transaction) =>
                  staticWriter.writeAttached(transaction, appStartInfo)
              : null,
        );

        if (standaloneEmitter != null) {
          await standaloneEmitter.emit(appStartInfo);
        }

        await displayTracking;
      },
      cancel: () {},
    );
  }

  _NativeAppStartHandler _createStreamHandler({
    required Hub hub,
    required SentryFlutterOptions options,
  }) {
    final timeToDisplayTracker = options.timeToDisplayTrackerV2;
    timeToDisplayTracker.prepareAppStart();
    final streamWriter = StreamAppStartSpanWriter(hub: hub);
    final StandaloneAppStartEmitter? standaloneEmitter =
        options.enableStandaloneAppStartTracing
            ? StreamStandaloneAppStartEmitter(
                hub: hub,
                writer: streamWriter,
              )
            : null;

    return _NativeAppStartHandler(
      track: (appStartInfo) async {
        timeToDisplayTracker.trackAppStart(
          startTimestamp: appStartInfo.start,
          ttidEndTimestamp: appStartInfo.end,
          attachAppStart: standaloneEmitter == null
              ? (rootSpan) => streamWriter.writeAttached(rootSpan, appStartInfo)
              : null,
        );

        if (standaloneEmitter != null) {
          await standaloneEmitter.emit(appStartInfo);
        }
      },
      cancel: timeToDisplayTracker.cancelCurrentRoute,
    );
  }
}

final class _NativeAppStartHandler {
  _NativeAppStartHandler({
    required this.track,
    required this.cancel,
  });

  final Future<void> Function(AppStartInfo appStartInfo) track;
  final void Function() cancel;
}
