import 'tracing.dart';

class SentrySpan {
  SentrySpanContext context;
  DateTime? timestamp;
  DateTime? startTimestamp;
  late bool isFinished;
  // SentryTracer tracer;
  final Map<String, dynamic> _extras = {};
  final Map<String, dynamic> _tags = {};

  SentrySpan(
    // this.tracer,
    this.context,
  );
}
