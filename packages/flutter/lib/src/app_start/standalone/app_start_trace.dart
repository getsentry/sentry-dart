import 'dart:async';

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

/// Returns the later endpoint used to measure an extended App Start.
@internal
DateTime resolveAppStartMeasurementEnd(
  DateTime appStartEndTimestamp,
  DateTime? extensionEndTimestamp,
) =>
    extensionEndTimestamp != null &&
            extensionEndTimestamp.isAfter(appStartEndTimestamp)
        ? extensionEndTimestamp
        : appStartEndTimestamp;

/// Lifecycle-independent operations for a standalone app-start trace.
@internal
abstract interface class AppStartTrace {
  bool tryExtend(DateTime startTimestamp);

  ISentrySpan? get extendedSpan;

  SentrySpanV2? get extendedSpanV2;

  Future<void> finishExtended(DateTime endTimestamp);

  void recordFirstFrame(DateTime endTimestamp);

  void finish(DateTime endTimestamp);

  FutureOr<void> close();
}
