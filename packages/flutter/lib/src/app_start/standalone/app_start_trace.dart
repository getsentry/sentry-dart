import 'dart:async';

import 'package:meta/meta.dart';

@internal
const standaloneAppStartRootName = 'App Start';

@internal
const standaloneAppStartIdleTimeout = Duration(seconds: 3);

@internal
const standaloneAppStartFinalTimeout = Duration(seconds: 30);

/// Lifecycle-independent operations for a standalone app-start trace.
@internal
abstract interface class AppStartTrace {
  void recordFirstFrame(DateTime endTimestamp);

  void finish(DateTime endTimestamp);

  FutureOr<void> close();
}
