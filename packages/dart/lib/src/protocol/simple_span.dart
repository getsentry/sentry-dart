import '../../sentry.dart';

class SimpleSpan extends Span {
  final SpanId _spanId;
  final Hub _hub;
  final DateTime _startTimestamp;
  @override
  final Span? parentSpan;
  final Map<String, SentryAttribute> _attributes = {};
  late final Span _segmentSpan;
  late final SentryId _traceId;

  String _name;
  SpanV2Status _status = SpanV2Status.ok;
  DateTime? _endTimestamp;
  bool _isFinished = false;

  SimpleSpan({
    required String name,
    this.parentSpan,
    Hub? hub,
  })  : _spanId = SpanId.newId(),
        _hub = hub ?? HubAdapter(),
        _startTimestamp = DateTime.now().toUtc(),
        _name = name {
    // If there's a parent, use its segment span; otherwise this span is the segment root
    _segmentSpan = parentSpan?.segmentSpan ?? this;
    _traceId = _hub.scope.propagationContext.traceId;
  }

  @override
  SentryId get traceId => _traceId;

  @override
  SpanId get spanId => _spanId;

  @override
  String get name => _name;

  @override
  set name(String value) => _name = value;

  @override
  SpanV2Status get status => _status;

  @override
  set status(SpanV2Status value) => _status = value;

  @override
  DateTime? get endTimestamp => _endTimestamp;

  @override
  Map<String, SentryAttribute> get attributes => Map.unmodifiable(_attributes);

  @override
  bool get isFinished => _isFinished;

  @override
  Span get segmentSpan => _segmentSpan;

  @override
  void setAttribute(String key, SentryAttribute value) {
    _attributes[key] = value;
  }

  @override
  void setAttributes(Map<String, SentryAttribute> attributes) {
    _attributes.addAll(attributes);
  }

  @override
  void end({DateTime? endTimestamp}) {
    if (_isFinished) {
      return;
    }
    _endTimestamp = (endTimestamp ?? DateTime.now()).toUtc();
    _isFinished = true;
    _hub.captureSpan(this);
  }

  @override
  Map<String, dynamic> toJson() {
    double toUnixSeconds(DateTime timestamp) =>
        timestamp.microsecondsSinceEpoch / 1000000;

    return {
      'trace_id': _traceId.toString(),
      'span_id': _spanId.toString(),
      'is_segment': parentSpan == null,
      'name': _name,
      'status': _status.name,
      'end_timestamp':
          _endTimestamp == null ? null : toUnixSeconds(_endTimestamp!),
      'start_timestamp': toUnixSeconds(_startTimestamp),
      if (parentSpan != null) 'parent_span_id': parentSpan?.spanId.toString(),
      if (parentSpan == null) 'is_segment': true,
      if (_attributes.isNotEmpty)
        'attributes':
            _attributes.map((key, value) => MapEntry(key, value.toJson())),
    };
  }
}
