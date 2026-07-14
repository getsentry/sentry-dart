import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';

/// Lifecycle-independent operations for a standalone app-start trace.
@internal
abstract interface class AppStartTrace {
  bool tryCreateExtension(DateTime startTimestamp);

  ISentrySpan? get activeStaticExtension;

  SentrySpanV2? get activeStreamingExtension;

  void finishExtension();

  void recordNaturalEnd(DateTime endTimestamp);

  FutureOr<void> close();
}
