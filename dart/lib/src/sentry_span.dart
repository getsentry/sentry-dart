import 'hub.dart';
import 'protocol/span_status.dart';

import 'sentry_tracer.dart';
import 'tracing.dart';
import 'utils.dart';

class SentrySpan extends ISentrySpan {
  final SentrySpanContext _context;
  DateTime? _timestamp;
  final DateTime _startTimestamp = getUtcDateTime();
  final Hub _hub;

  final SentryTracer _tracer;
  final Map<String, dynamic> _data = {};
  dynamic _throwable;

  SentrySpan(
    this._tracer,
    this._context,
    this._hub,
  );

  @override
  Future<void> finish({SpanStatus? status}) async {
    if (status != null) {
      _context.status = status;
    }
    _timestamp = getUtcDateTime();

    // associate error
    if (_throwable != null) {
      _hub.setSpanContext(_throwable, this, _tracer.name);
    }
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
    return _tracer.startChildWithParentSpanId(
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
  DateTime? get endTimestamp => _timestamp;

  @override
  SentrySpanContext get context => _context;

  @override
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

  @override
  bool get finished => _timestamp != null;

  @override
  Map<String, dynamic> get data => _data;

  @override
  dynamic get throwable => _throwable;

  @override
  set throwable(throwable) => _throwable = throwable;
}
