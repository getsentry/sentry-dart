// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'dart:ui';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../frame_callback_handler.dart';
import '../native/sentry_native_binding.dart';
import 'app_start_info.dart';
import 'app_start_tracker.dart';
import 'native_app_start_parser.dart';

/// Feeds native app start data into the [AppStartTracker] once the first
/// frame timing is available.
class NativeAppStartIntegration extends Integration<SentryFlutterOptions> {
  NativeAppStartIntegration(
    this._frameCallbackHandler,
    this._native,
    this._appStartTracker,
  );

  @internal
  static const integrationName = 'NativeAppStart';

  final FrameCallbackHandler _frameCallbackHandler;
  final SentryNativeBinding _native;
  final AppStartTracker _appStartTracker;

  bool _allowProcessing = true;

  @override
  void call(Hub hub, SentryFlutterOptions options) async {
    if (!options.isTracingEnabled()) {
      options.log(SentryLevel.info,
          'Skipping $integrationName integration because tracing is disabled.');
      return;
    }

    _appStartTracker.prepare(hub, options);

    void timingsCallback(List<FrameTiming> timings) async {
      if (!_allowProcessing) {
        return;
      }
      // Set immediately to prevent multiple executions
      // we only care about the first frame
      _allowProcessing = false;

      try {
        final appStartEnd = DateTime.fromMicrosecondsSinceEpoch(timings.first
            .timestampInMicroseconds(FramePhase.rasterFinishWallTime));

        final nativeAppStart = await _native.fetchNativeAppStart();
        final AppStartInfo? appStartInfo = nativeAppStart == null
            ? null
            : parseNativeAppStart(nativeAppStart, appStartEnd);
        if (appStartInfo == null) {
          _appStartTracker.cancel(options);
          return;
        }

        await _appStartTracker.track(hub, options, appStartInfo);
      } catch (exception, stackTrace) {
        options.log(
          SentryLevel.error,
          'Error while capturing native app start',
          exception: exception,
          stackTrace: stackTrace,
        );
        if (options.automatedTestMode) {
          rethrow;
        }
      } finally {
        _frameCallbackHandler.removeTimingsCallback(timingsCallback);
      }
    }

    _frameCallbackHandler.addTimingsCallback(timingsCallback);
    options.sdk.addIntegration(integrationName);
    if (options.enableStandaloneAppStartTracing) {
      options.sdk.addFeature(SentryFeatures.standaloneAppStartTracing);
    }
  }
}
