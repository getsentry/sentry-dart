import 'package:meta/meta.dart';

import '../sentry.dart';

@internal
class SentryTracerFinishStatus {
  final bool finishing;
  final SpanStatus? status;

  SentryTracerFinishStatus.finishing(this.status) : finishing = true;

  SentryTracerFinishStatus.notFinishing()
      : finishing = false,
        status = null;
}
