part of '../telemetry.dart';

typedef OnSpanEndCallback = void Function(RecordingSentrySpanV2 span);

final class RecordingSentrySpanV2
    with MutableAttributesMixin
    implements SentrySpanV2 {
  final SpanId _spanId;
  final RecordingSentrySpanV2? _parentSpan;
  final ClockProvider _clock;
  final OnSpanEndCallback _onSpanEnd;
  final SdkLogCallback _log;
  final DateTime _startTimestamp;
  final SentryId _traceId;
  late final RecordingSentrySpanV2 _segmentSpan;

  // Mutable span state.
  SentrySpanStatusV2 _status = SentrySpanStatusV2.ok;
  DateTime? _endTimestamp;
  bool _isFinished = false;
  String _name;

  RecordingSentrySpanV2({
    required String name,
    required SentryId traceId,
    required OnSpanEndCallback onSpanEnd,
    required SdkLogCallback log,
    required ClockProvider clock,
    required RecordingSentrySpanV2? parentSpan,
  })  : _spanId = SpanId.newId(),
        _parentSpan = parentSpan,
        _name = name,
        _clock = clock,
        _onSpanEnd = onSpanEnd,
        _log = log,
        _startTimestamp = clock(),
        _traceId = parentSpan?.traceId ?? traceId {
    _segmentSpan = parentSpan?.segmentSpan ?? this;
  }

  @override
  SentryId get traceId => _traceId;

  @override
  SpanId get spanId => _spanId;

  @override
  RecordingSentrySpanV2? get parentSpan => _parentSpan;

  @override
  String get name => _name;

  @override
  set name(String value) => _name = value;

  @override
  SentrySpanStatusV2 get status => _status;

  @override
  set status(SentrySpanStatusV2 value) => _status = value;

  @override
  DateTime? get endTimestamp => _endTimestamp;

  @override
  void end({DateTime? endTimestamp}) {
    if (_isFinished) return;

    _endTimestamp = endTimestamp?.toUtc() ?? _clock();
    _isFinished = true;

    _onSpanEnd(this);
    _log(SentryLevel.debug, 'Span ended with endTimestamp: $_endTimestamp');
  }

  Map<String, dynamic> toJson() {
    double toUnixSeconds(DateTime timestamp) =>
        timestamp.microsecondsSinceEpoch / 1000000;

    return {
      'trace_id': _traceId.toString(),
      'span_id': _spanId.toString(),
      'is_segment': _parentSpan == null,
      'name': _name,
      'status': _status.name,
      'end_timestamp':
          _endTimestamp == null ? null : toUnixSeconds(_endTimestamp!),
      'start_timestamp': toUnixSeconds(_startTimestamp),
      'attributes':
          attributes.map((key, value) => MapEntry(key, value.toJson())),
      if (_parentSpan != null) 'parent_span_id': _parentSpan.spanId.toString(),
    };
  }

  bool get isFinished => _isFinished;
  RecordingSentrySpanV2 get segmentSpan => _segmentSpan;
}
