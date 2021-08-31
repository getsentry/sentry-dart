import 'protocol/span_status.dart';

import 'tracing.dart';

class SentrySpan implements ISentrySpan {
  final SentrySpanContext _context;
  DateTime? _timestamp;
  final DateTime _startTimestamp = DateTime.now();
  // late bool isFinished;
  final SentryTracer _tracer;
  final Map<String, dynamic> _extras = {};
  final Map<String, dynamic> _tags = {};

  SentrySpan(
    this._tracer,
    this._context,
  );

  @override
  void finish({SpanStatus? status}) {
    _context.status = status ?? _context.status;
    _timestamp = DateTime.now();
  }

  @override
  void removeData(String key) {
    _extras.remove(key);
  }

  @override
  void removeTag(String key) {
    _tags.remove(key);
  }

  @override
  void setData(String key, value) {
    _extras[key] = value;
  }

  @override
  void setTag(String key, String value) {
    _tags[key] = value;
  }

  @override
  ISentrySpan startChild(
    String operation, {
    String? description,
  }) {
    return _tracer.startChildWithParentId(
      _context.spanId,
      operation,
      description: description,
    );
  }

  @override
  SpanStatus? get status => _context.status;

  @override
  DateTime get startTimestamp => _startTimestamp;

  @override
  DateTime? get timestamp => _timestamp;

  @override
  SentrySpanContext get context => _context;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{};
  }
}
