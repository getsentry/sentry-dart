import '../hub.dart';
import 'span_status.dart';

import '../sentry_tracer.dart';
import '../tracing.dart';
import '../utils.dart';

class SentrySpan extends ISentrySpan {
  final SentrySpanContext _context;
  DateTime? _timestamp;
  final DateTime _startTimestamp = getUtcDateTime();
  final Hub _hub;

  final SentryTracer _tracer;
  final Map<String, dynamic> _data = {};
  dynamic _throwable;

  SpanStatus? _status;
  final Map<String, String> _tags = {};

  @override
  bool? sampled;

  SentrySpan(
    this._tracer,
    this._context,
    this._hub, {
    bool? sampled,
  }) {
    this.sampled = sampled;
  }

  @override
  Future<void> finish({SpanStatus? status}) async {
    if (status != null) {
      _status = status;
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
    _tags.remove(key);
  }

  @override
  void setData(String key, value) {
    _data[key] = value;
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
    return _tracer.startChildWithParentSpanId(
      _context.spanId,
      operation,
      description: description,
    );
  }

  @override
  SpanStatus? get status => _status;

  @override
  set status(SpanStatus? status) => _status = status;

  @override
  DateTime get startTimestamp => _startTimestamp;

  @override
  DateTime? get endTimestamp => _timestamp;

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
    if (status != null) {
      json['status'] = status.toString();
    }
    if (_tags.isNotEmpty) {
      json['tags'] = _tags;
    }
    return json;
  }

  @override
  bool get finished => _timestamp != null;

  @override
  dynamic get throwable => _throwable;

  @override
  set throwable(throwable) => _throwable = throwable;

  Map<String, String> get tags => _tags;

  Map<String, dynamic> get data => _data;
}
