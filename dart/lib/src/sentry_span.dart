import 'protocol/span_status.dart';

import 'tracing.dart';

class SentrySpan implements ISentrySpan {
  SentrySpanContext context;
  DateTime? timestamp;
  DateTime? startTimestamp;
  late bool isFinished;
  SentryTracer tracer;
  final Map<String, dynamic> _extras = {};
  final Map<String, dynamic> _tags = {};

  SentrySpan(
    this.tracer,
    this.context,
  );

  @override
  void finish({SpanStatus? status}) {
    // TODO: implement finish
  }

  @override
  void removeData(String key) {
    // TODO: implement removeData
  }

  @override
  void removeTag(String key) {
    // TODO: implement removeTag
  }

  @override
  void setData(String key, value) {
    // TODO: implement setData
  }

  @override
  void setTag(String key, String value) {
    // TODO: implement setTag
  }

  @override
  ISentrySpan startChild(String operation, {String? description}) {
    // TODO: implement startChild
    throw UnimplementedError();
  }
}
