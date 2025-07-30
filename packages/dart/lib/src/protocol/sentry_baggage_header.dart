import 'package:meta/meta.dart';

import '../sentry_baggage.dart';

@immutable
class SentryBaggageHeader {
  static const _traceHeader = 'baggage';

  SentryBaggageHeader(this.value);

  final String value;

  String get name => _traceHeader;

  factory SentryBaggageHeader.fromBaggage(SentryBaggage baggage) {
    return SentryBaggageHeader(baggage.toHeaderString());
  }
}
