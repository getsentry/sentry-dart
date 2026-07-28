// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../app_start_timing.dart';
import 'app_start_trace.dart';

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
  /// [extension] is where an app-start extension stands, which can move the
  /// measured endpoint past the first frame or withhold it entirely.
  /// [deadlineExceeded] marks a root torn down by its hard deadline.
  factory AppStartVitals.resolve({
    required AppStartTiming timing,
    required String screen,
    required DateTime? endTimestamp,
    required AppStartExtensionOutcome extension,
    required bool deadlineExceeded,
  }) {
    final measurementEnd = _resolveMeasurementEnd(endTimestamp, extension);
    return AppStartVitals._(
      type: timing.type,
      screen: screen,
      duration: measurementEnd == null || deadlineExceeded
          ? null
          : timing.reportableDurationUntil(measurementEnd),
    );
  }

  /// The endpoint the app start is measured to, or `null` when it has none.
  ///
  /// An extension that has started but not settled leaves the app start still
  /// running, so there is nothing to report yet — better to withhold the
  /// duration than to report a window that ends mid-extension.
  static DateTime? _resolveMeasurementEnd(
    DateTime? endTimestamp,
    AppStartExtensionOutcome extension,
  ) {
    if (endTimestamp == null || !extension.isSettled) {
      return null;
    }

    final extensionEnd = extension.endTimestamp;
    return extensionEnd != null && extensionEnd.isAfter(endTimestamp)
        ? extensionEnd
        : endTimestamp;
  }

  /// Cold or warm.
  ///
  /// Only the static payload stamps this from here. The streaming root and its
  /// children carry the type from the moment they are created, so
  /// `StreamingAppStartTrace` reads it off [AppStartTiming] instead — it is
  /// already on the span before there is anything to resolve.
  final AppStartType type;

  /// The route observed at the first frame, or the `root /` fallback.
  final String screen;

  /// Time from process start to the first frame, or to the end of an extension
  /// that outlasted it.
  ///
  /// `null` when the app start has no measurable duration: no first frame
  /// arrived, an extension is still running so the window has no end yet, or
  /// the root hit its hard deadline and the window is truncated. Type and
  /// screen are still reported in those cases.
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
