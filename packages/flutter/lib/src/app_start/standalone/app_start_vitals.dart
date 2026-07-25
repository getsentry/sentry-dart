// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../app_start_timing.dart';

/// What a standalone app-start root reports, resolved once for both trace
/// lifecycles.
///
/// The third stage of the app-start data flow, derived from [AppStartTiming]
/// — see its doc for the full chain.
///
/// The static and streaming implementations write these values in different
/// payload dialects — measurements versus attributes — but must agree on
/// *what* is reported. Keeping the rules here is what makes that agreement
/// checkable in one place rather than by diffing two enrichment methods.
///
/// Deliberately scoped to `standalone/` rather than shared with the
/// `ui_load_attached/` path, which reports overlapping values through its own
/// code. That path is slated for removal in v10, leaving standalone as the
/// only way app starts are reported, so the two are kept unentangled and the
/// duplication resolves when it is deleted.
@internal
final class AppStartVitals {
  AppStartVitals._({
    required this.type,
    required this.screen,
    required this.duration,
  });

  /// Resolves the reported signal for a root that is about to be captured.
  ///
  /// [endTimestamp] is the first frame, or `null` when none arrived.
  /// [deadlineExceeded] marks a root torn down by its hard deadline.
  factory AppStartVitals.resolve({
    required AppStartTiming timing,
    required String screen,
    required DateTime? endTimestamp,
    required bool deadlineExceeded,
  }) =>
      AppStartVitals._(
        type: timing.type,
        screen: screen,
        duration: endTimestamp == null || deadlineExceeded
            ? null
            : timing.reportableDurationUntil(endTimestamp),
      );

  /// Cold or warm.
  ///
  /// Only the static payload stamps this from here. The streaming root and its
  /// children carry the type from the moment they are created, so
  /// `StreamingAppStartTrace` reads it off [AppStartTiming] instead — it is
  /// already on the span before there is anything to resolve.
  final AppStartType type;

  /// The route observed at the first frame, or the `root /` fallback.
  final String screen;

  /// Time from process start to the first frame.
  ///
  /// `null` when the app start has no measurable duration: no first frame
  /// arrived, or the root hit its hard deadline and the window is truncated.
  /// Type and screen are still reported in that case.
  final Duration? duration;

  /// The cold/warm measurement for the static payload, or `null` when there is
  /// no [duration] to report.
  SentryMeasurement? get measurement {
    final duration = this.duration;
    if (duration == null) {
      return null;
    }
    return type == AppStartType.cold
        ? SentryMeasurement.coldAppStart(duration)
        : SentryMeasurement.warmAppStart(duration);
  }

  /// The cold/warm attribute key for the streaming payload.
  ///
  /// Emitted alongside the unified `app.vitals.start.value`, which is set to
  /// replace these split keys.
  String get durationAttributeKey => type == AppStartType.cold
      ? SemanticAttributesConstants.appVitalsStartColdValue
      : SemanticAttributesConstants.appVitalsStartWarmValue;
}
