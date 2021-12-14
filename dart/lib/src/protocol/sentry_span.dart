import '../hub.dart';
import '../protocol.dart';

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
    if (finished) {
      return;
    }

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
    if (finished) {
      return;
    }

    _data.remove(key);
  }

  @override
  void removeTag(String key) {
    if (finished) {
      return;
    }

    _tags.remove(key);
  }

  @override
  void setData(String key, value) {
    if (finished) {
      return;
    }

    _data[key] = value;
  }

  @override
  void setTag(String key, String value) {
    if (finished) {
      return;
    }

    _tags[key] = value;
  }

  @override
  ISentrySpan startChild(
    String operation, {
    String? description,
  }) {
    if (finished) {
      return NoOpSentrySpan();
    }

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

  @override
  SentryTraceHeader toSentryTrace() => SentryTraceHeader(
        _context.traceId,
        _context.spanId,
        sampled: sampled,
      );
}
