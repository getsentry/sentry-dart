import '../../sentry.dart';

class SimpleSpan implements Span {
  final SpanId _spanId;
  final Hub _hub;
  @override
  final Span? parentSpan;
  final Map<String, SentryAttribute> _attributes = {};

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
        _name = name;

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
    // TODO: implement toJson
    throw UnimplementedError();
  }
}
