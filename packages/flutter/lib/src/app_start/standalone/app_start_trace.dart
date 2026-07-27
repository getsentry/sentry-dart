import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

@internal
const standaloneAppStartRootName = 'App Start';

@internal
const standaloneAppStartIdleTimeout = Duration(seconds: 3);

@internal
const standaloneAppStartFinalTimeout = Duration(seconds: 30);

@internal
const standaloneExtendedAppStartName = 'Extended App Start';

/// Where an app-start extension stands when the root is enriched.
@internal
typedef AppStartExtensionOutcome = ({bool completed, DateTime? endTimestamp});

/// Returns the endpoint a standalone app start reports up to, or `null` when it
/// has none.
///
/// An extension that has started but not completed leaves the app start still
/// running, so there is nothing to report yet — both trace implementations must
/// stay silent rather than report a window that ends mid-extension.
@internal
DateTime? resolveAppStartMeasurementEnd(
  DateTime? appStartEndTimestamp,
  AppStartExtensionOutcome extension,
) {
  if (appStartEndTimestamp == null || !extension.completed) {
    return null;
  }

  final extensionEndTimestamp = extension.endTimestamp;
  return extensionEndTimestamp != null &&
          extensionEndTimestamp.isAfter(appStartEndTimestamp)
      ? extensionEndTimestamp
      : appStartEndTimestamp;
}

/// How far a standalone app-start trace has progressed.
///
/// Shared by both trace implementations, which advance through it identically.
@internal
enum AppStartTraceState {
  /// The root is open and can still accept children.
  ///
  /// Also covers deadline teardown, which is why a first frame arriving
  /// mid-teardown is still recorded — see `StaticAppStartTrace`.
  open,

  /// The root finished and its enrichment ran. Terminal.
  completed,

  /// Torn down by SDK close.
  ///
  /// Transient in the static implementation: flushing the root fires its
  /// finish callback, so enrichment still runs and advances the state to
  /// [completed].
  closed;

  bool get isTerminal => this == completed || this == closed;
}

/// The standalone app-start root, emitted independently of the initial
/// `ui.load`.
///
/// One implementation per trace lifecycle — `StaticAppStartTrace` and
/// `StreamingAppStartTrace` — each reporting the same duration, type, screen,
/// hierarchy and status through its lifecycle's own payload. What gets
/// reported is resolved once in `AppStartVitals`; the implementations differ
/// only in how they write it.
///
/// See `docs/standalone-app-start-spec.md` for the contract.
@internal
abstract interface class AppStartTrace {
  bool tryExtend(DateTime startTimestamp);

  ISentrySpan? get extendedSpan;

  SentrySpanV2? get extendedSpanV2;

  Future<void> finishExtended(DateTime endTimestamp);

  /// Ends the first-frame span and marks [endTimestamp] as the app-start end.
  ///
  /// The root is not ended here — it stays open for its idle timeout so late
  /// children can still attach.
  void recordFirstFrame(DateTime endTimestamp);

  /// Abandons the trace on SDK close, flushing whatever is still open.
  Future<void> close();
}
