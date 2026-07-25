import 'dart:async';

import 'package:meta/meta.dart';

@internal
const standaloneAppStartRootName = 'App Start';

@internal
const standaloneAppStartIdleTimeout = Duration(seconds: 3);

@internal
const standaloneAppStartFinalTimeout = Duration(seconds: 30);

/// Lifecycle state shared by the standalone app-start trace implementations.
@internal
enum AppStartTraceState {
  /// The root is open and can still accept children.
  open,

  /// Deadline teardown is in progress: descendants first, then the root.
  finalizing,

  /// The root finished and its enrichment ran. Terminal.
  completed,

  /// Torn down by SDK close. Enrichment may still follow the flush.
  closed;

  bool get isTerminal => this == completed || this == closed;
}

/// Lifecycle-independent operations for a standalone app-start trace.
@internal
abstract interface class AppStartTrace {
  /// Ends the first-frame span and marks [endTimestamp] as the app-start end.
  ///
  /// The root is not ended here — it stays open for its idle timeout so late
  /// children can still attach.
  void recordFirstFrame(DateTime endTimestamp);

  FutureOr<void> close();
}
