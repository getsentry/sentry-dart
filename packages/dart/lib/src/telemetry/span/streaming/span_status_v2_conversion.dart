import 'package:meta/meta.dart';

import '../transaction/span_status.dart';
import 'sentry_span_status_v2.dart';

/// Maps a streaming span status to the [SpanStatus] used by event trace
/// contexts and the transaction span API.
@internal
SpanStatus spanStatusFromV2(SentrySpanStatusV2 status) => switch (status) {
  SentrySpanStatusV2.ok => const SpanStatus.ok(),
  SentrySpanStatusV2.error => const SpanStatus.unknownError(),
};
