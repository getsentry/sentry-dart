import 'dart:async';

import 'package:meta/meta.dart';

/// Lifecycle-independent operations for a standalone app-start trace.
@internal
abstract interface class AppStartTrace {
  void recordNaturalEnd(DateTime endTimestamp);

  FutureOr<void> close();
}
