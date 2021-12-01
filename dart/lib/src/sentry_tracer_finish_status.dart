import 'package:meta/meta.dart';

import '../sentry.dart';

@internal
class SentryTracerFinishStatus {
  final bool finishing;
  final SpanStatus? status;

  SentryTracerFinishStatus.finishing(SpanStatus? status)
      : finishing = true,
        status = status;

  SentryTracerFinishStatus.notFinishing()
      : finishing = false,
        status = null;
}
