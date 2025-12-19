part of 'sentry_span_v2.dart';

typedef SpanEndedCallback = void Function(RecordingSentrySpanV2);

/// Primary implementation of [SentrySpanV2].
///
/// This class contains the full implementation including internal methods
/// needed by the SDK for telemetry processing.
@internal
final class RecordingSentrySpanV2 implements SentrySpanV2, JsonEncodable {
  final SpanId _spanId;
  final RecordingSentrySpanV2? _parentSpan;
  final Map<String, SentryAttribute> _attributes = {};
  final SentrySpanContextV2 _context;

  late final DateTime _startTimestamp;
  late final RecordingSentrySpanV2 _segmentSpan;
  late final SentryId _traceId;

  /// The frozen DSC (Dynamic Sampling Context) for this segment.
  /// Once frozen, this is the permanent DSC for all spans in the segment.
  /// Only set on segment spans (root of local trace segment).
  SentryTraceContextHeader? _frozenDsc;

  String _name;
  SentrySpanStatusV2 _status = SentrySpanStatusV2.ok;
  DateTime? _endTimestamp;
  bool _isFinished = false;

  RecordingSentrySpanV2({
    required String name,
    required SentrySpanContextV2 context,
    RecordingSentrySpanV2? parentSpan,
  })  : _spanId = SpanId.newId(),
        _name = name,
        _parentSpan = parentSpan,
        _context = context {
    _segmentSpan = _parentSpan?.segmentSpan ?? this;
    _startTimestamp = context.clock();
    _traceId = _parentSpan?.traceId ?? context.traceId;
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

  bool get isFinished => _isFinished;

  /// The segment span (root span of the local trace segment).
  ///
  /// Used for grouping spans into envelopes.
  RecordingSentrySpanV2 get segmentSpan => _segmentSpan;

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
  void end({DateTime? endTimestamp}) {
    if (_isFinished) {
      return;
    }
    _endTimestamp = (endTimestamp?.toUtc() ?? _context.clock());
    _isFinished = true;
    _context.onSpanEnded(this);
  }

  /// Serializes this span to JSON for transmission to Sentry.
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
      if (_attributes.isNotEmpty)
        'attributes':
            _attributes.map((key, value) => MapEntry(key, value.toJson())),
    };
  }
}

extension DynamicSamplingContext on RecordingSentrySpanV2 {
  /// Gets the frozen DSC (Dynamic Sampling Context) for this span's segment.
  ///
  /// On first access, creates and freezes the DSC with current segment state.
  /// Subsequent calls return the same frozen instance.
  SentryTraceContextHeader getOrCreateDsc() =>
      _segmentSpan._frozenDsc ??= _context.createDsc(this);
}
