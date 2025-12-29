part of 'sentry_span_v2.dart';

typedef OnSpanEndCallback = void Function(RecordingSentrySpanV2 span);

final class RecordingSentrySpanV2 implements SentrySpanV2 {
  final SpanId _spanId = SpanId.newId();
  final RecordingSentrySpanV2? _parentSpan;
  final ClockProvider _clock;
  final OnSpanEndCallback _onSpanEnd;
  final SdkLogCallback _log;
  final DateTime _startTimestamp;
  final SentryId _traceId;
  final RecordingSentrySpanV2? _segmentSpan;
  final Map<String, SentryAttribute> _attributes = {};

  // Mutable span state.
  SentrySpanStatusV2 _status = SentrySpanStatusV2.ok;
  DateTime? _endTimestamp;
  String _name;

  RecordingSentrySpanV2({
    required SentryId traceId,
    required String name,
    required OnSpanEndCallback onSpanEnd,
    required SdkLogCallback log,
    required ClockProvider clock,
    required RecordingSentrySpanV2? parentSpan,
  })  : _traceId = parentSpan?.traceId ?? traceId,
        _name = name,
        _parentSpan = parentSpan,
        _clock = clock,
        _onSpanEnd = onSpanEnd,
        _log = log,
        _startTimestamp = clock(),
        _segmentSpan = parentSpan?.segmentSpan ?? parentSpan;

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
    if (isEnded) return;

    _endTimestamp = (endTimestamp ?? _clock()).toUtc();

    _onSpanEnd(this);
    _log(SentryLevel.debug, 'Span ended with endTimestamp: $_endTimestamp');
  }

  /// The segment span for this span.
  ///
  /// The segment span is the root of the span tree.
  /// Returns `null` if this span is the segment span.
  RecordingSentrySpanV2 get segmentSpan => _segmentSpan ?? this;

  @override
  bool get isEnded => _endTimestamp != null;

  @override
  Map<String, SentryAttribute> get attributes => Map.unmodifiable(_attributes);

  @override
  void setAttribute(String key, SentryAttribute value) {
    _attributes[key] = value;
  }

  @override
  void setAttributes(Map<String, SentryAttribute> attributes) {
    _attributes.addAll(attributes);
  }

  @override
  void removeAttribute(String key) {
    _attributes.remove(key);
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
      // Create a copy of attributes in case attributes are mutated during serialization
      if (_attributes.isNotEmpty)
        'attributes': Map.from(_attributes)
            .map((key, value) => MapEntry(key, value.toJson())),
      if (_parentSpan != null) 'parent_span_id': _parentSpan.spanId.toString(),
    };
  }
}
