import 'dart:async';

import 'package:meta/meta.dart';

@internal
const standaloneAppStartRootName = 'App Start';

/// Idle auto-finish after the natural first-frame end.
@internal
const standaloneAppStartIdleTimeout = Duration(seconds: 3);

/// Hard deadline from trace creation when first frame never arrives.
@internal
const standaloneAppStartFinalTimeout = Duration(seconds: 30);

/// Lifecycle-independent operations for a standalone app-start trace.
@internal
abstract interface class AppStartTrace {
  void recordFirstFrame(DateTime endTimestamp);

  void finish(DateTime endTimestamp);

  FutureOr<void> close();
}
