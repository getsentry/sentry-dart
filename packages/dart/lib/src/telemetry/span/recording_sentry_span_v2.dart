part of 'sentry_span_v2.dart';

/// Factory for creating a [SentryTraceContextHeader] from a [RecordingSentrySpanV2].
typedef DscCreator = SentryTraceContextHeader Function(
    RecordingSentrySpanV2 span);

/// Called when a span ends, allowing the span to be processed or buffered.
typedef OnSpanEndCallback = void Function(RecordingSentrySpanV2 span);

/// A span that records timing and attribute data for performance monitoring.
///
/// This span captures start/end timestamps, attributes, and status. When
/// [end] is called, the span is passed to [OnSpanEndCallback] for processing.
final class RecordingSentrySpanV2 implements SentrySpanV2 {
  final SpanId _spanId = SpanId.newId();
  final RecordingSentrySpanV2? _parentSpan;
  final ClockProvider _clock;
  final OnSpanEndCallback _onSpanEnd;
  final DateTime _startTimestamp;
  final SentryId _traceId;
  final RecordingSentrySpanV2? _segmentSpan;
  final DscCreator _dscCreator;
  final Map<String, SentryAttribute> _attributes = {};

  // Mutable span state.
  SentrySpanStatusV2 _status = SentrySpanStatusV2.ok;
  DateTime? _endTimestamp;
  String _name;
  SentryTraceContextHeader? _frozenDsc;

  RecordingSentrySpanV2({
    required SentryId traceId,
    required String name,
    required OnSpanEndCallback onSpanEnd,
    required SdkLogCallback log,
    required ClockProvider clock,
    required RecordingSentrySpanV2? parentSpan,
    required DscCreator dscCreator,
  })  : _traceId = parentSpan?.traceId ?? traceId,
        _name = name,
        _parentSpan = parentSpan,
        _clock = clock,
        _onSpanEnd = onSpanEnd,
        _startTimestamp = clock(),
        _segmentSpan = parentSpan?.segmentSpan,
        _dscCreator = dscCreator;

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
    internalLogger.debug(
        'Span $name ended with start timestamp: $_startTimestamp, end timestamp: $_endTimestamp');
  }

  /// The local root span of this trace segment.
  ///
  /// In distributed tracing, each service (Flutter, backend, etc.) has its own
  /// segment. Returns `this` if this span is the segment root.
  RecordingSentrySpanV2 get segmentSpan => _segmentSpan ?? this;

  /// Freezes and returns this span's DSC (only meaningful for segment spans).
  SentryTraceContextHeader _getOrCreateDsc() =>
      _frozenDsc ??= _dscCreator(this);

  /// The segment's Dynamic Sampling Context (DSC) header.
  ///
  /// Created lazily on first access and frozen for the segment's lifetime.
  /// All spans in the same segment share this DSC.
  SentryTraceContextHeader resolveDsc() => segmentSpan._getOrCreateDsc();

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
