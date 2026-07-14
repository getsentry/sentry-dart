// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../native/native_app_start.dart';
import '../utils/internal_logger.dart';
import 'app_start_constants.dart';

const _maxSnapshotAge = Duration(seconds: 60);

@internal
enum AppStartType { cold, warm }

/// Intrinsic app-start timing captured before the first Flutter frame.
@internal
final class AppStartData {
  AppStartData({
    required this.type,
    required this.processStartTimestamp,
    required this.pluginRegistrationTimestamp,
    required this.sentrySetupTimestamp,
    required this.nativePhaseIntervals,
  });

  final AppStartType type;
  final DateTime processStartTimestamp;
  final DateTime pluginRegistrationTimestamp;
  final DateTime sentrySetupTimestamp;
  final List<AppStartPhaseInterval> nativePhaseIntervals;

  Iterable<AppStartBreakdownPhase> get completedBreakdownPhases sync* {
    for (final phase in nativePhaseIntervals) {
      yield AppStartBreakdownPhase(
        operation: SentrySpanOperations.appStartNative,
        description: phase.description,
        startTimestamp: phase.startTimestamp,
        endTimestamp: phase.endTimestamp,
      );
    }
    yield AppStartBreakdownPhase(
      operation: SentrySpanOperations.appStartPluginRegistration,
      description: appStartPluginRegistrationDescription,
      startTimestamp: processStartTimestamp,
      endTimestamp: pluginRegistrationTimestamp,
    );
    yield AppStartBreakdownPhase(
      operation: SentrySpanOperations.appStartSentrySetup,
      description: appStartSentrySetupDescription,
      startTimestamp: pluginRegistrationTimestamp,
      endTimestamp: sentrySetupTimestamp,
    );
  }
}

@internal
final class AppStartBreakdownPhase {
  AppStartBreakdownPhase({
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

@internal
final class AppStartPhaseInterval {
  AppStartPhaseInterval({
    required this.startTimestamp,
    required this.endTimestamp,
    required this.description,
  });

  final DateTime startTimestamp;
  final DateTime endTimestamp;
  final String description;
}

/// App-start timing finalized by the first Flutter frame.
@internal
final class FinalizedAppStartData {
  FinalizedAppStartData({required this.snapshot, required this.endTimestamp});

  final AppStartData snapshot;
  final DateTime endTimestamp;

  Duration get duration => endTimestamp.difference(
        snapshot.processStartTimestamp,
      );

  SentryMeasurement toMeasurement() => snapshot.type == AppStartType.cold
      ? SentryMeasurement.coldAppStart(duration)
      : SentryMeasurement.warmAppStart(duration);

  String get typeOperation => 'app.start.${snapshot.type.name}';

  String get typeDescription =>
      snapshot.type == AppStartType.cold ? 'Cold Start' : 'Warm Start';
}

@internal
List<AppStartPhaseInterval> parseNativeAppStartPhases(
  NativeAppStart nativeAppStart, {
  DateTime? earliestTimestamp,
  DateTime? latestTimestamp,
}) {
  final phases = <AppStartPhaseInterval>[];
  for (final entry in nativeAppStart.nativeSpanTimes.entries) {
    try {
      final value = entry.value;
      final startMilliseconds = value['startTimestampMsSinceEpoch'] as int;
      final endMilliseconds = value['stopTimestampMsSinceEpoch'] as int;
      final start =
          DateTime.fromMillisecondsSinceEpoch(startMilliseconds).toUtc();
      final end = DateTime.fromMillisecondsSinceEpoch(endMilliseconds).toUtc();
      if (end.isBefore(start) ||
          (earliestTimestamp != null && start.isBefore(earliestTimestamp)) ||
          (latestTimestamp != null && end.isAfter(latestTimestamp))) {
        continue;
      }
      phases.add(
        AppStartPhaseInterval(
          startTimestamp: start,
          endTimestamp: end,
          description: entry.key as String,
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

/// Parses a start-only native timing snapshot for standalone app start.
@internal
AppStartData? parseStandaloneAppStart(
  NativeAppStart nativeAppStart, {
  required DateTime sentrySetupTimestamp,
  required DateTime snapshotTimestamp,
}) {
  final processStart =
      DateTime.fromMillisecondsSinceEpoch(nativeAppStart.appStartTime).toUtc();
  final pluginRegistration = DateTime.fromMillisecondsSinceEpoch(
    nativeAppStart.pluginRegistrationTime,
  ).toUtc();
  final setup = sentrySetupTimestamp.toUtc();
  final snapshot = snapshotTimestamp.toUtc();

  final age = snapshot.difference(processStart);
  if (age.isNegative ||
      age > _maxSnapshotAge ||
      pluginRegistration.isBefore(processStart) ||
      setup.isBefore(pluginRegistration) ||
      setup.isAfter(snapshot)) {
    return null;
  }

  return AppStartData(
    type: nativeAppStart.isColdStart ? AppStartType.cold : AppStartType.warm,
    processStartTimestamp: processStart,
    pluginRegistrationTimestamp: pluginRegistration,
    sentrySetupTimestamp: setup,
    nativePhaseIntervals: parseNativeAppStartPhases(
      nativeAppStart,
      earliestTimestamp: processStart,
      latestTimestamp: snapshot,
    ),
  );
}
