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

/// Which part of the startup timeline a phase covers.
@internal
enum AppStartPhaseKind { native, pluginRegistration, sentrySetup }

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
///    [AppStartPhase]s, with launches that cannot be reported rejected
///    outright by the parse entry points below.
/// 3. `AppStartVitals` — what a standalone root actually reports: type,
///    screen, and a duration that may be absent.
/// 4. The span payload — measurements on the static path, attributes on the
///    streaming one.
///
/// [AppStartType], [AppStartPhaseKind] and [AppStartPhase] are parts of this
/// stage rather than stages of their own.
///
/// Stages 1 and 2 stay separate because validity is not a property of the
/// payload. The parse entry points below take a caller-supplied ceiling and
/// a Dart-side setup timestamp, so the same [NativeAppStart] can be accepted
/// for one caller and rejected for another.
@internal
final class AppStartTiming {
  AppStartTiming({
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

  Iterable<AppStartPhase> get nativePhases =>
      phases.where((phase) => phase.kind == AppStartPhaseKind.native);

  Duration durationUntil(DateTime endTimestamp) =>
      endTimestamp.difference(processStartTimestamp);

  /// The duration safe to report, or `null` when the window is not a
  /// plausible launch — longer than the 60s ceiling, or running backwards
  /// because the wall clock was adjusted mid-startup.
  ///
  /// The parse entry points already apply this ceiling, but only against their
  /// own `validUntil`. [tryParseAtSnapshot] validates against SDK init, so a
  /// launch it accepts can still render its first frame arbitrarily later — a
  /// process launched into the background and foregrounded a minute on would
  /// otherwise report as a very slow cold start.
  ///
  /// Dropped rather than clamped, because a clamped 60s is indistinguishable
  /// from a genuine one, and the parse rejects for the same reason.
  Duration? reportableDurationUntil(DateTime endTimestamp) {
    final duration = durationUntil(endTimestamp);
    return duration.isNegative || duration > _maxAppStartAge ? null : duration;
  }

  SentryMeasurement measurementUntil(DateTime endTimestamp) {
    final duration = durationUntil(endTimestamp);
    return type == AppStartType.cold
        ? SentryMeasurement.coldAppStart(duration)
        : SentryMeasurement.warmAppStart(duration);
  }

  /// Parses native timing for the eager standalone root, opened at SDK init.
  ///
  /// [snapshotTimestamp] is when the native snapshot was taken, so every
  /// breakdown phase that snapshot reports can be retained. The first frame is
  /// recorded later through the open first-frame span, so this is **not** the
  /// app-start measurement end.
  static AppStartTiming? tryParseAtSnapshot(
    NativeAppStart nativeAppStart, {
    required DateTime sentrySetupTimestamp,
    required DateTime snapshotTimestamp,
    required int maxNativePhases,
  }) =>
      _tryParse(
        nativeAppStart,
        sentrySetupTimestamp: sentrySetupTimestamp,
        validUntil: snapshotTimestamp,
        maxNativePhases: maxNativePhases,
      );

  /// Parses native timing retrospectively for the ui.load path, after the
  /// first frame has been drawn.
  ///
  /// [firstFrameTimestamp] is both the validation ceiling and the natural
  /// app-start measurement end (extend, if any, can still push the vital
  /// later).
  static AppStartTiming? tryParseAtFirstFrame(
    NativeAppStart nativeAppStart, {
    required DateTime sentrySetupTimestamp,
    required DateTime firstFrameTimestamp,
    required int maxNativePhases,
  }) =>
      _tryParse(
        nativeAppStart,
        sentrySetupTimestamp: sentrySetupTimestamp,
        validUntil: firstFrameTimestamp,
        maxNativePhases: maxNativePhases,
      );

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
  /// Native phases that end after it are dropped; other failures reject the
  /// entire parse.
  ///
  /// [maxNativePhases] bounds how many native phases become spans. The count
  /// comes from the platform, so without a ceiling a misbehaving native SDK
  /// could push arbitrarily many children onto the root.
  static AppStartTiming? _tryParse(
    NativeAppStart nativeAppStart, {
    required DateTime sentrySetupTimestamp,
    required DateTime validUntil,
    required int maxNativePhases,
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

    return AppStartTiming(
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
        maxNativePhases: maxNativePhases,
      ),
    );
  }

  static List<AppStartPhase> _buildPhases({
    required NativeAppStart nativeAppStart,
    required DateTime processStart,
    required DateTime pluginRegistration,
    required DateTime setup,
    required DateTime latestTimestamp,
    required int maxNativePhases,
  }) =>
      [
        ..._parseNativePhases(
          nativeAppStart,
          earliestTimestamp: processStart,
          latestTimestamp: latestTimestamp,
          maxNativePhases: maxNativePhases,
        ),
        AppStartPhase(
          kind: AppStartPhaseKind.pluginRegistration,
          description: appStartPluginRegistrationDescription,
          startTimestamp: processStart,
          endTimestamp: pluginRegistration,
        ),
        AppStartPhase(
          kind: AppStartPhaseKind.sentrySetup,
          description: appStartSentrySetupDescription,
          startTimestamp: pluginRegistration,
          endTimestamp: setup,
        ),
      ];

  static List<AppStartPhase> _parseNativePhases(
    NativeAppStart nativeAppStart, {
    required DateTime earliestTimestamp,
    required DateTime latestTimestamp,
    required int maxNativePhases,
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
    if (phases.length <= maxNativePhases) {
      return phases;
    }
    internalLogger.warning(
      'Dropping ${phases.length - maxNativePhases} native app-start phases '
      'over the limit of $maxNativePhases',
    );
    return phases.sublist(0, maxNativePhases);
  }
}

/// Per-phase span op for the standalone app-start path, where every phase
/// carries its own op. The ui.load path instead labels each phase with the
/// cold/warm op from [UiLoadAppStartTypeSpans].
@internal
extension StandaloneAppStartPhaseSpans on AppStartPhaseKind {
  String get operation => switch (this) {
        AppStartPhaseKind.native => SentrySpanOperations.appStartNative,
        AppStartPhaseKind.pluginRegistration =>
          SentrySpanOperations.appStartPluginRegistration,
        AppStartPhaseKind.sentrySetup =>
          SentrySpanOperations.appStartSentrySetup,
      };
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
