// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../native/native_app_start.dart';
import '../utils/internal_logger.dart';

/// Rejects app starts older / longer than 60s (late init, backgrounded
/// process, OS forking, or unreproducible outliers).
const _maxAppStartAge = Duration(seconds: 60);

/// Description for everything before `SentryFlutter.init` began.
///
/// Deliberately not split at `pluginRegistrationTime`. That timestamp records
/// when Sentry's *native* plugin happened to be attached, which moves with
/// plugin ordering and marks no milestone in the app's own startup — so it
/// bounds no span, and is only used to reject an incoherent payload.
@internal
const appStartPreInitDescription = 'Pre-Init Startup';

@internal
enum AppStartType { cold, warm }

/// Which part of the startup timeline a phase covers.
@internal
enum AppStartPhaseKind { native, preInit }

/// A span-ready app-start phase (native, plugin registration, or setup).
@internal
final class AppStartPhase {
  AppStartPhase({
    required this.kind,
    required this.description,
    required this.startTimestamp,
    required this.endTimestamp,
  });

  final AppStartPhaseKind kind;
  final String description;
  final DateTime startTimestamp;
  final DateTime endTimestamp;
}

/// Validated app-start timing snapshot before the first Flutter frame.
///
/// The middle stage of how app-start data flows through the SDK:
///
/// 1. [NativeAppStart] — the raw platform-channel payload: epoch
///    milliseconds, untyped span times, shape checks only.
/// 2. [AppStartTiming] — this type. Validated [DateTime]s and typed
///    [AppStartPhase]s, with self-contradicting timelines rejected outright by
///    [tryParse].
/// 3. `AppStartVitals` — what a standalone root actually reports: type,
///    screen, and a duration that may be absent.
/// 4. The span payload — measurements on the static path, attributes on the
///    streaming one.
///
/// [AppStartType], [AppStartPhaseKind] and [AppStartPhase] are parts of this
/// stage rather than stages of their own.
///
/// Stages 1 and 2 stay separate because a coherent timeline is not yet a
/// reportable one. Plausibility depends on when the launch is measured to, so
/// it is asked separately through [reportableDurationUntil] — the same
/// [NativeAppStart] can be reportable for one caller and not another.
@internal
final class AppStartTiming {
  AppStartTiming({
    required this.type,
    required this.processStartTimestamp,
    required this.sentrySetupTimestamp,
    required this.phases,
  });

  final AppStartType type;
  final DateTime processStartTimestamp;
  final DateTime sentrySetupTimestamp;

  /// Native detail phases plus the pre-init roll-up, ready to become spans.
  final List<AppStartPhase> phases;

  Iterable<AppStartPhase> get nativePhases =>
      phases.where((phase) => phase.kind == AppStartPhaseKind.native);

  /// The duration safe to report, or `null` when the window is not a
  /// plausible launch — longer than the 60s ceiling, or running backwards
  /// because the wall clock was adjusted mid-startup.
  ///
  /// This is the only plausibility gate, so every caller that reports an app
  /// start goes through it. Native hands over an OS process start with no hint
  /// of how long ago it was: a pre-warmed or backgrounded launch can begin
  /// minutes before the user ever saw the app, and nothing but the duration to
  /// a caller-chosen end reveals that.
  ///
  /// Dropped rather than clamped, because a clamped 60s is indistinguishable
  /// from a genuine one.
  Duration? reportableDurationUntil(DateTime endTimestamp) {
    final duration = endTimestamp.difference(processStartTimestamp);
    return duration.isNegative || duration > _maxAppStartAge ? null : duration;
  }

  SentryMeasurement measurementFor(Duration duration) =>
      type == AppStartType.cold
      ? SentryMeasurement.coldAppStart(duration)
      : SentryMeasurement.warmAppStart(duration);

  /// Parses native app-start timing into span-ready data, or `null` when the
  /// payload is not a coherent timeline — plugin registration before process
  /// start, or setup before plugin registration.
  ///
  /// [sentrySetupTimestamp] is when `SentryFlutter.init` started (Dart-side).
  /// It ends the [AppStartPhaseKind.preInit] phase.
  ///
  /// Coherent is not the same as reportable: this only rejects a timeline that
  /// contradicts itself, which needs nothing beyond the payload. Whether the
  /// launch is plausible enough to report is [reportableDurationUntil], asked
  /// once the caller knows which end it measures to.
  static AppStartTiming? tryParse(
    NativeAppStart nativeAppStart, {
    required DateTime sentrySetupTimestamp,
  }) {
    final processStart = DateTime.fromMillisecondsSinceEpoch(
      nativeAppStart.appStartTime,
    ).toUtc();
    final pluginRegistration = DateTime.fromMillisecondsSinceEpoch(
      nativeAppStart.pluginRegistrationTime,
    ).toUtc();
    final setup = sentrySetupTimestamp.toUtc();

    if (pluginRegistration.isBefore(processStart) ||
        setup.isBefore(pluginRegistration)) {
      return null;
    }

    return AppStartTiming(
      type: nativeAppStart.isColdStart ? AppStartType.cold : AppStartType.warm,
      processStartTimestamp: processStart,
      sentrySetupTimestamp: setup,
      phases: _buildPhases(
        nativeAppStart: nativeAppStart,
        processStart: processStart,
        setup: setup,
      ),
    );
  }

  static List<AppStartPhase> _buildPhases({
    required NativeAppStart nativeAppStart,
    required DateTime processStart,
    required DateTime setup,
  }) => [
    ..._parseNativePhases(nativeAppStart, earliestTimestamp: processStart),
    AppStartPhase(
      kind: AppStartPhaseKind.preInit,
      description: appStartPreInitDescription,
      startTimestamp: processStart,
      endTimestamp: setup,
    ),
  ];

  static List<AppStartPhase> _parseNativePhases(
    NativeAppStart nativeAppStart, {
    required DateTime earliestTimestamp,
  }) {
    final phases = <AppStartPhase>[];
    for (final entry in nativeAppStart.nativeSpanTimes.entries) {
      try {
        final value = entry.value;
        final startMilliseconds = value['startTimestampMsSinceEpoch'] as int;
        final endMilliseconds = value['stopTimestampMsSinceEpoch'] as int;
        final start = DateTime.fromMillisecondsSinceEpoch(
          startMilliseconds,
        ).toUtc();
        final end = DateTime.fromMillisecondsSinceEpoch(
          endMilliseconds,
        ).toUtc();
        if (end.isBefore(start) || start.isBefore(earliestTimestamp)) {
          continue;
        }
        phases.add(
          AppStartPhase(
            kind: AppStartPhaseKind.native,
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

/// Per-phase span op for standalone app-start, where every phase carries its
/// own op. Cold/warm is reported on the `app.start` root as attributes.
@internal
extension StandaloneAppStartPhaseSpans on AppStartPhaseKind {
  String get operation => switch (this) {
    AppStartPhaseKind.native => SentrySpanOperations.appStartNative,
    AppStartPhaseKind.preInit => SentrySpanOperations.appStartPreInit,
  };
}
