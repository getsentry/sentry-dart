import 'dart:async';

import '../hub.dart';
import '../protocol.dart';

import '../sentry_tracer.dart';
import '../tracing.dart';
import '../utils.dart';

typedef OnFinishedCallback = Future<void> Function({DateTime? endTimestamp});

class SentrySpan extends ISentrySpan {
  final SentrySpanContext _context;
  DateTime? _endTimestamp;
  late final DateTime _startTimestamp;
  final Hub _hub;

  final SentryTracer _tracer;
  final Map<String, dynamic> _data = {};
  dynamic _throwable;

  SpanStatus? _status;
  final Map<String, String> _tags = {};
  OnFinishedCallback? _finishedCallback;

  @override
  final SentryTracesSamplingDecision? samplingDecision;

  SentrySpan(
    this._tracer,
    this._context,
    this._hub, {
    DateTime? startTimestamp,
    this.samplingDecision,
    OnFinishedCallback? finishedCallback,
  }) {
    _startTimestamp = startTimestamp?.toUtc() ?? _hub.options.clock();
    _finishedCallback = finishedCallback;
  }

  @override
  Future<void> finish({SpanStatus? status, DateTime? endTimestamp}) async {
    if (finished) {
      return;
    }

    if (status != null) {
      _status = status;
    }

    if (endTimestamp == null) {
      _endTimestamp = _hub.options.clock();
    } else if (endTimestamp.isBefore(_startTimestamp)) {
      _hub.options.logger(
        SentryLevel.warning,
        'End timestamp ($endTimestamp) cannot be before start timestamp ($_startTimestamp)',
      );
      _endTimestamp = _hub.options.clock();
    } else {
      _endTimestamp = endTimestamp.toUtc();
    }

    // associate error
    if (_throwable != null) {
      _hub.setSpanContext(_throwable, this, _tracer.name);
    }
    await _finishedCallback?.call(endTimestamp: _endTimestamp);
    return super.finish(status: status, endTimestamp: _endTimestamp);
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
    DateTime? startTimestamp,
  }) {
    if (finished) {
      return NoOpSentrySpan();
    }

    if (startTimestamp?.isBefore(_startTimestamp) ?? false) {
      _hub.options.logger(
        SentryLevel.warning,
        "Start timestamp ($startTimestamp) cannot be before parent span's start timestamp ($_startTimestamp). Returning NoOpSpan.",
      );
      return NoOpSentrySpan();
    }

    return _tracer.startChildWithParentSpanId(
      _context.spanId,
      operation,
      description: description,
      startTimestamp: startTimestamp,
    );
  }

  @override
  SpanStatus? get status => _status;

  @override
  set status(SpanStatus? status) => _status = status;

  @override
  DateTime get startTimestamp => _startTimestamp;

  @override
  DateTime? get endTimestamp => _endTimestamp;

  @override
  SentrySpanContext get context => _context;

  Map<String, dynamic> toJson() {
    final json = _context.toJson();
    json['start_timestamp'] =
        formatDateAsIso8601WithMillisPrecision(_startTimestamp);
    if (_endTimestamp != null) {
      json['timestamp'] =
          formatDateAsIso8601WithMillisPrecision(_endTimestamp!);
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
  bool get finished => _endTimestamp != null;

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
        sampled: samplingDecision?.sampled,
      );

  @override
  void setMeasurement(
    String name,
    num value, {
    SentryMeasurementUnit? unit,
  }) {
    _tracer.setMeasurement(name, value, unit: unit);
  }

  @override
  SentryBaggageHeader? toBaggageHeader() => _tracer.toBaggageHeader();

  @override
  SentryTraceContextHeader? traceContext() => _tracer.traceContext();

  @override
  void scheduleFinish() => _tracer.scheduleFinish();
}
