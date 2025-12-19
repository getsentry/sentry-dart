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
  final ClockProvider _clock;
  final SpanEndedCallback _onSpanEnded;
  final TraceContextHeaderFactory _dscFactory;
  final SdkLogCallback _log;
  final DateTime _startTimestamp;
  final SentryId _traceId;
  late final RecordingSentrySpanV2 _segmentSpan;

  // Mutable span state.
  SentrySpanStatusV2 _status = SentrySpanStatusV2.ok;
  DateTime? _endTimestamp;
  bool _isFinished = false;
  String _name;
  final Map<String, SentryAttribute> _attributes = {};
  SentryTraceContextHeader? _frozenDsc;

  RecordingSentrySpanV2({
    required String name,
    required SentryId defaultTraceId,
    required SpanEndedCallback onSpanEnded,
    required TraceContextHeaderFactory dscFactory,
    required SdkLogCallback log,
    required ClockProvider clock,
    required RecordingSentrySpanV2? parentSpan,
  }) : _spanId = SpanId.newId(),
       _parentSpan = parentSpan,
       _name = name,
       _clock = clock,
       _onSpanEnded = onSpanEnded,
       _dscFactory = dscFactory,
       _log = log,
       _startTimestamp = clock(),
       _traceId = parentSpan?.traceId ?? defaultTraceId {
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
    if (_isFinished) return;

    _endTimestamp = endTimestamp?.toUtc() ?? _clock();
    _isFinished = true;

    _onSpanEnded(this);
    _log(SentryLevel.debug, 'Span ended with endTimestamp: $_endTimestamp');
  }

  @override
  Map<String, dynamic> toJson() {
    double toUnixSeconds(DateTime timestamp) =>
        timestamp.microsecondsSinceEpoch / 1000000;

    return {
      'trace_id': _traceId.toString(),
      'span_id': _spanId.toString(),
      'is_segment': _parentSpan == null,
      'name': _name,
      'status': _status.name,
      'end_timestamp': _endTimestamp == null
          ? null
          : toUnixSeconds(_endTimestamp!),
      'start_timestamp': toUnixSeconds(_startTimestamp),
      if (_parentSpan != null) 'parent_span_id': _parentSpan!.spanId.toString(),
      if (_attributes.isNotEmpty)
        'attributes': _attributes.map((k, v) => MapEntry(k, v.toJson())),
    };
  }

  bool get isFinished => _isFinished;

  /// The segment root span (root of the local trace segment).
  RecordingSentrySpanV2 get segmentSpan => _segmentSpan;

  /// Returns the segment’s frozen DSC, creating it once if needed.
  SentryTraceContextHeader getOrCreateDsc() =>
      _segmentSpan._frozenDsc ??= _dscFactory(this);
}
