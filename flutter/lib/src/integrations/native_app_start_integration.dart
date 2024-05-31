// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../frame_callback_handler.dart';
import '../native/sentry_native.dart';
import '../event_processor/native_app_start_event_processor.dart';

/// Integration which handles communication with native frameworks in order to
/// enrich [SentryTransaction] objects with app start data for mobile vitals.
class NativeAppStartIntegration extends Integration<SentryFlutterOptions> {
  NativeAppStartIntegration(this._native, this._frameCallbackHandler,
      {Hub? hub})
      : _hub = hub ?? HubAdapter();

  final SentryNative _native;
  final FrameCallbackHandler _frameCallbackHandler;
  final Hub _hub;

  /// Timeout duration to wait for the app start info to be fetched.
  static const _timeoutDuration = Duration(seconds: 30);

  /// We filter out App starts more than 60s
  static const _maxAppStartMillis = 60000;

  static Completer<AppStartInfo?> _appStartCompleter =
      Completer<AppStartInfo?>();
  static AppStartInfo? _appStartInfo;

  @internal
  static bool isIntegrationTest = false;

  @internal
  static void setAppStartInfo(AppStartInfo? appStartInfo) {
    _appStartInfo = appStartInfo;
    if (_appStartCompleter.isCompleted) {
      _appStartCompleter = Completer<AppStartInfo?>();
    }
    _appStartCompleter.complete(appStartInfo);
  }

  @internal
  static Future<AppStartInfo?> getAppStartInfo() {
    if (_appStartInfo != null) {
      return Future.value(_appStartInfo);
    }
    return _appStartCompleter.future
        .timeout(_timeoutDuration, onTimeout: () => null);
  }

  @visibleForTesting
  static void clearAppStartInfo() {
    _appStartInfo = null;
    _appStartCompleter = Completer<AppStartInfo?>();
  }

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    if (isIntegrationTest) {
      final appStartInfo = AppStartInfo(
        AppStartType.cold,
        start: DateTime.now(),
        end: DateTime.now().add(const Duration(milliseconds: 100)),
        pluginRegistration:
            DateTime.now().add(const Duration(milliseconds: 50)),
        sentrySetupStart: DateTime.now().add(const Duration(milliseconds: 60)),
        nativeSpanTimes: [],
      );
      setAppStartInfo(appStartInfo);
      return;
    }

    if (_native.didFetchAppStart) {
      return;
    }

    _frameCallbackHandler.addPostFrameCallback((timeStamp) async {
      final nativeAppStart = await _native.fetchNativeAppStart();
      if (nativeAppStart == null) {
        setAppStartInfo(null);
        return;
      }

      final sentrySetupStartDateTime = SentryFlutter.sentrySetupStartTime;
      if (sentrySetupStartDateTime == null) {
        setAppStartInfo(null);
        return;
      }

      final appStartDateTime = DateTime.fromMillisecondsSinceEpoch(
          nativeAppStart.appStartTime.toInt());
      final pluginRegistrationDateTime = DateTime.fromMillisecondsSinceEpoch(
          nativeAppStart.pluginRegistrationTime);
      DateTime? appStartEndDateTime;

      if (options.autoAppStart) {
        // We only assign the current time if it's not already set - this is useful in tests
        _native.appStartEnd ??= options.clock();
        appStartEndDateTime = _native.appStartEnd;

        final duration = appStartEndDateTime?.difference(appStartDateTime);

        // We filter out app start more than 60s.
        // This could be due to many different reasons.
        // If you do the manual init and init the SDK too late and it does not
        // compute the app start end in the very first Screen.
        // If the process starts but the App isn't in the foreground.
        // If the system forked the process earlier to accelerate the app start.
        // And some unknown reasons that could not be reproduced.
        // We've seen app starts with hours, days and even months.
        if (duration != null && duration.inMilliseconds > _maxAppStartMillis) {
          setAppStartInfo(null);
          return;
        }
      }

      List<TimeSpan> nativeSpanTimes = [];
      for (final entry in nativeAppStart.nativeSpanTimes.entries) {
        try {
          final startTimestampMs =
              entry.value['startTimestampMsSinceEpoch'] as int;
          final endTimestampMs =
              entry.value['stopTimestampMsSinceEpoch'] as int;
          nativeSpanTimes.add(TimeSpan(
            start: DateTime.fromMillisecondsSinceEpoch(startTimestampMs),
            end: DateTime.fromMillisecondsSinceEpoch(endTimestampMs),
            description: entry.key as String,
          ));
        } catch (e) {
          _hub.options.logger(
              SentryLevel.warning, 'Failed to parse native span times: $e');
          continue;
        }
      }

      // We want to sort because the native spans are not guaranteed to be in order.
      // Performance wise this won't affect us since the native span amount is very low.
      nativeSpanTimes.sort((a, b) => a.start.compareTo(b.start));

      final appStartInfo = AppStartInfo(
          nativeAppStart.isColdStart ? AppStartType.cold : AppStartType.warm,
          start: appStartDateTime,
          end: appStartEndDateTime,
          pluginRegistration: pluginRegistrationDateTime,
          sentrySetupStart: sentrySetupStartDateTime,
          nativeSpanTimes: nativeSpanTimes);

      setAppStartInfo(appStartInfo);

      // When we don't have a SentryNavigatorObserver, a TTID transaction
      // is not created therefore we need to create a transaction ourselves.
      // We detect this by checking if the currentRouteName is null.
      // This is a workaround since there is no api that tells us if
      // the navigator observer exists and has been attached.
      // The navigator observer also triggers much earlier so if it was attached
      // it would have already set the routeName and the isCreated flag.
      // The currentRouteName is always set during a didPush triggered
      // by the navigator observer.
      if (!SentryNavigatorObserver.isCreated &&
          SentryNavigatorObserver.currentRouteName == null) {
        const screenName = SentryNavigatorObserver.rootScreenName;
        final transaction = hub.startTransaction(
            screenName, SentrySpanOperations.uiLoad,
            startTimestamp: appStartInfo.start);
        final ttidSpan = transaction.startChild(
            SentrySpanOperations.uiTimeToInitialDisplay,
            description: '$screenName initial display',
            startTimestamp: appStartInfo.start);
        await ttidSpan.finish(endTimestamp: appStartInfo.end);
        await transaction.finish(endTimestamp: appStartInfo.end);
      }
    });

    options.addEventProcessor(NativeAppStartEventProcessor(_native, hub: hub));

    options.sdk.addIntegration('nativeAppStartIntegration');
  }
}

enum AppStartType { cold, warm }

class AppStartInfo {
  AppStartInfo(
    this.type, {
    required this.start,
    required this.pluginRegistration,
    required this.sentrySetupStart,
    required this.nativeSpanTimes,
    this.end,
  });

  final AppStartType type;
  final DateTime start;
  final List<TimeSpan> nativeSpanTimes;

  // We allow the end to be null, since it might be set at a later time
  // with setAppStartEnd when autoAppStart is disabled
  DateTime? end;

  final DateTime pluginRegistration;
  final DateTime sentrySetupStart;

  Duration? get duration => end?.difference(start);

  SentryMeasurement? toMeasurement() {
    final duration = this.duration;
    if (duration == null) {
      return null;
    }
    return type == AppStartType.cold
        ? SentryMeasurement.coldAppStart(duration)
        : SentryMeasurement.warmAppStart(duration);
  }

  String get appStartTypeOperation => 'app.start.${type.name}';

  String get appStartTypeDescription =>
      type == AppStartType.cold ? 'Cold Start' : 'Warm Start';
  final pluginRegistrationDescription = 'App start to plugin registration';
  final sentrySetupDescription = 'Before Sentry Init Setup';
  final firstFrameRenderDescription = 'First frame render';
}

class TimeSpan {
  TimeSpan({required this.start, required this.end, required this.description});

  final DateTime start;
  final DateTime end;
  final String description;
}
