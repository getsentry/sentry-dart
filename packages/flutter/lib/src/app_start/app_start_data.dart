// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../native/native_app_start.dart';
import '../utils/internal_logger.dart';

/// Rejects app starts older / longer than 60s (late init, backgrounded
/// process, OS forking, or unreproducible outliers).
const _maxAppStartAge = Duration(seconds: 60);

@internal
const appStartPluginRegistrationDescription =
    'App start to plugin registration';

@internal
const appStartSentrySetupDescription = 'Before Sentry Init Setup';

/// Description for the first-frame phase (end timestamp arrives after parse).
@internal
const appStartFirstFrameRenderDescription = 'First frame render';

@internal
enum AppStartType { cold, warm }

/// A span-ready app-start phase (native, plugin registration, or setup).
@internal
final class AppStartPhase {
  AppStartPhase({
    required this.operation,
    required this.description,
    required this.startTimestamp,
    required this.endTimestamp,
  });

  final String operation;
  final String description;
  final DateTime startTimestamp;
  final DateTime endTimestamp;
}

/// Validated app-start timing snapshot before the first Flutter frame.
@internal
final class AppStartData {
  AppStartData({
    required this.type,
    required this.processStartTimestamp,
    required this.pluginRegistrationTimestamp,
    required this.sentrySetupTimestamp,
    required this.phases,
  });

  final AppStartType type;
  final DateTime processStartTimestamp;
  final DateTime pluginRegistrationTimestamp;
  final DateTime sentrySetupTimestamp;

  /// Native + plugin registration + sentry setup phases, ready to become spans.
  final List<AppStartPhase> phases;

  Iterable<AppStartPhase> get nativePhases => phases.where(
        (phase) => phase.operation == SentrySpanOperations.appStartNative,
      );

  Duration durationUntil(DateTime endTimestamp) =>
      endTimestamp.difference(processStartTimestamp);

  SentryMeasurement measurementUntil(DateTime endTimestamp) {
    final duration = durationUntil(endTimestamp);
    return type == AppStartType.cold
        ? SentryMeasurement.coldAppStart(duration)
        : SentryMeasurement.warmAppStart(duration);
  }

  /// Parses and validates native app-start timing into span-ready data.
  ///
  /// Returns `null` when the launch should not be reported as an app start
  /// (impossible ordering, process start in the future, or older than 60s
  /// relative to [validUntil]).
  ///
  /// [sentrySetupTimestamp] is when Flutter Sentry finished init (Dart-side).
  /// It ends the "Before Sentry Init Setup" phase and must fall between
  /// plugin registration and [validUntil].
  ///
  /// [validUntil] is the latest timestamp allowed for anything validated
  /// here — native process/plugin/phase times and [sentrySetupTimestamp].
  /// Callers choose it based on how much of the timeline they can trust
  /// at parse time:
  ///
  /// - **Eager standalone** (root opened at SDK init): pass setup time.
  ///   Completed breakdown phases only run through setup; first frame is
  ///   recorded later via the open first-frame barrier, so [validUntil]
  ///   is **not** the app-start measurement end.
  /// - **Retrospective ui.load** (parse after first frame): pass first-frame
  ///   end. That is both the validation ceiling and the natural measurement
  ///   end (extend, if any, can still push the vital later).
  ///
  /// Native phases that end after [validUntil] are dropped; other failures
  /// reject the entire parse.
  static AppStartData? tryParse(
    NativeAppStart nativeAppStart, {
    required DateTime sentrySetupTimestamp,
    required DateTime validUntil,
  }) {
    final processStart = DateTime.fromMillisecondsSinceEpoch(
      nativeAppStart.appStartTime,
    ).toUtc();
    final pluginRegistration = DateTime.fromMillisecondsSinceEpoch(
      nativeAppStart.pluginRegistrationTime,
    ).toUtc();
    final setup = sentrySetupTimestamp.toUtc();
    final until = validUntil.toUtc();

    final age = until.difference(processStart);
    if (age.isNegative ||
        age > _maxAppStartAge ||
        pluginRegistration.isBefore(processStart) ||
        setup.isBefore(pluginRegistration) ||
        setup.isAfter(until)) {
      return null;
    }

    return AppStartData(
      type: nativeAppStart.isColdStart ? AppStartType.cold : AppStartType.warm,
      processStartTimestamp: processStart,
      pluginRegistrationTimestamp: pluginRegistration,
      sentrySetupTimestamp: setup,
      phases: _buildPhases(
        nativeAppStart: nativeAppStart,
        processStart: processStart,
        pluginRegistration: pluginRegistration,
        setup: setup,
        latestTimestamp: until,
      ),
    );
  }

  static List<AppStartPhase> _buildPhases({
    required NativeAppStart nativeAppStart,
    required DateTime processStart,
    required DateTime pluginRegistration,
    required DateTime setup,
    required DateTime latestTimestamp,
  }) =>
      [
        ..._parseNativePhases(
          nativeAppStart,
          earliestTimestamp: processStart,
          latestTimestamp: latestTimestamp,
        ),
        AppStartPhase(
          operation: SentrySpanOperations.appStartPluginRegistration,
          description: appStartPluginRegistrationDescription,
          startTimestamp: processStart,
          endTimestamp: pluginRegistration,
        ),
        AppStartPhase(
          operation: SentrySpanOperations.appStartSentrySetup,
          description: appStartSentrySetupDescription,
          startTimestamp: pluginRegistration,
          endTimestamp: setup,
        ),
      ];

  static List<AppStartPhase> _parseNativePhases(
    NativeAppStart nativeAppStart, {
    required DateTime earliestTimestamp,
    required DateTime latestTimestamp,
  }) {
    final phases = <AppStartPhase>[];
    for (final entry in nativeAppStart.nativeSpanTimes.entries) {
      try {
        final value = entry.value;
        final startMilliseconds = value['startTimestampMsSinceEpoch'] as int;
        final endMilliseconds = value['stopTimestampMsSinceEpoch'] as int;
        final start =
            DateTime.fromMillisecondsSinceEpoch(startMilliseconds).toUtc();
        final end =
            DateTime.fromMillisecondsSinceEpoch(endMilliseconds).toUtc();
        if (end.isBefore(start) ||
            start.isBefore(earliestTimestamp) ||
            end.isAfter(latestTimestamp)) {
          continue;
        }
        phases.add(
          AppStartPhase(
            operation: SentrySpanOperations.appStartNative,
            description: entry.key as String,
            startTimestamp: start,
            endTimestamp: end,
          ),
        );
      } catch (error, stackTrace) {
        internalLogger.warning(
          'Failed to parse native app-start phase',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    phases.sort((a, b) => a.startTimestamp.compareTo(b.startTimestamp));
    return phases;
  }
}

/// Nested-span op/description for the ui.load app-start path
/// (`app.start.cold` / `Cold Start`). Standalone uses `app.start` as the root
/// op and puts cold/warm in attributes instead.
@internal
extension UiLoadAppStartTypeSpans on AppStartType {
  String get operation => 'app.start.$name';

  String get description =>
      this == AppStartType.cold ? 'Cold Start' : 'Warm Start';
}
