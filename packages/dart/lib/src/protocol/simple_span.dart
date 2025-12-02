import 'package:meta/meta.dart';

import '../../sentry.dart';

class SimpleSpan implements Span {
  final Hub hub;
  final Map<String, SentryAttribute> _attributes = {};

  @override
  final Span? parentSpan;

  String _name;
  SpanV2Status _status = SpanV2Status.ok;
  DateTime? _endTimestamp;

  SimpleSpan({
    required String name,
    this.parentSpan,
    Hub? hub,
  })  : hub = hub ?? HubAdapter(),
        _name = name;

  @override
  DateTime? get endTimestamp => _endTimestamp;

  @override
  Map<String, SentryAttribute> get attributes => Map.unmodifiable(_attributes);

  @override
  String get name => _name;

  @override
  set name(String value) {
    _name = value;
  }

  @override
  SpanV2Status get status => _status;

  @override
  set status(SpanV2Status value) {
    _status = value;
  }

  @override
  void end({DateTime? endTimestamp}) {
    _endTimestamp = endTimestamp ?? DateTime.now().toUtc();
    hub.captureSpan(this);
  }

  @override
  void setAttribute(String key, SentryAttribute value) {
    _attributes[key] = value;
  }

  @override
  void setAttributes(Map<String, SentryAttribute> attributes) {
    _attributes.addAll(attributes);
  }

  @override
  Map<String, dynamic> toJson() {
    // TODO: implement toJson
    throw UnimplementedError();
  }
}
