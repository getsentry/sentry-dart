import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import '../../utils/internal_logger.dart';

@internal
const standaloneAppStartRootName = 'App Start';

@internal
const standaloneAppStartIdleTimeout = Duration(seconds: 3);

@internal
const standaloneAppStartFinalTimeout = Duration(seconds: 30);

@internal
const standaloneAppStartExtensionName = 'Extended App Start';

/// Records why an extension was turned down, so the public entry point and
/// both lifecycles read the same way in the logs.
///
/// The public entry point returns nothing, so a log is the only way a user
/// finds out their extension never opened.
@internal
void logAppStartExtensionRefusal(String reason) {
  internalLogger.info('Not extending the app start: $reason');
}

/// Records why a finish was turned down.
///
/// The counterpart to [logAppStartExtensionRefusal], and the more valuable of
/// the two: a finish is refused precisely when the app start has already been
/// reported, so the user is looking at a duration they expected the extension
/// to cover and nothing else would tell them why it does not.
@internal
void logAppStartExtensionFinishRefusal(String reason) {
  internalLogger.info('Not finishing the extended app start: $reason');
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
@internal
abstract interface class AppStartTrace {
  /// Opens the single extension span, keeping the app start open past the
  /// first frame until it is finished.
  ///
  /// Returns `false` when the extension was refused: one already exists, the
  /// first frame has already rendered, or the trace is winding down. Every
  /// refusal is logged, which is why the public entry point can discard this.
  bool tryExtend(DateTime startTimestamp);

  /// The running extension span on the static lifecycle, or `null` on the
  /// streaming one and once the extension is no longer running.
  ///
  /// There is one getter per span protocol because a caller parenting its own
  /// work under the extension needs the concrete type its lifecycle speaks.
  /// Each implementation answers for its own protocol and `null` for the other,
  /// so the pair follows `SentryFlutterOptions.traceLifecycle`.
  ISentrySpan? get extendedSpan;

  /// The running extension span on the streaming lifecycle, or `null` on the
  /// static one and once the extension is no longer running.
  ///
  /// See [extendedSpan] for why there is one getter per protocol.
  SentrySpanV2? get extendedSpanV2;

  /// Ends the extension span, releasing the app start to report.
  ///
  /// Descendants started under the extension are left running; they keep the
  /// root open on their own until they end or the root hits its deadline.
  Future<void> finishExtended(DateTime endTimestamp);

  /// Ends the first-frame span and marks [endTimestamp] as the app-start end.
  ///
  /// The root is not ended here — it stays open for its idle timeout so late
  /// children can still attach.
  void recordFirstFrame(DateTime endTimestamp);

  /// Abandons the trace on SDK close, flushing whatever is still open.
  Future<void> close();
}
