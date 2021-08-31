import 'protocol/span_status.dart';

import 'tracing.dart';
import 'utils.dart';

class SentrySpan implements ISentrySpan {
  final SentrySpanContext _context;
  DateTime? _timestamp;
  final DateTime _startTimestamp = getUtcDateTime();
  // late bool isFinished;
  final SentryTracer _tracer;
  final Map<String, dynamic> _data = {};
  // final Map<String, dynamic> _tags = {};

  SentrySpan(
    this._tracer,
    this._context,
  );

  @override
  void finish({SpanStatus? status}) {
    if (status != null) {
      _context.status = status;
    }
    _timestamp = getUtcDateTime();
  }

  @override
  void removeData(String key) {
    _data.remove(key);
  }

  @override
  void removeTag(String key) {
    context.tags.remove(key);
  }

  @override
  void setData(String key, value) {
    _data[key] = value;
  }

  @override
  void setTag(String key, String value) {
    context.tags[key] = value;
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
    final json = _context.toJson();
    json['start_timestamp'] =
        formatDateAsIso8601WithMillisPrecision(_startTimestamp);
    if (_timestamp != null) {
      json['timestamp'] = formatDateAsIso8601WithMillisPrecision(_timestamp!);
    }
    if (_data.isNotEmpty) {
      json['data'] = _data;
    }
    return json;
  }
}
