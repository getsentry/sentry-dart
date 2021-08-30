import 'tracing.dart';

class SentryTransactionContext extends SentrySpanContext {
  String name;
  late bool _parentSampled;

  SentryTransactionContext(
    this.name,
    String operation, {
    bool parentSampled = false,
  }) : super(
          operation: operation,
        ) {
    _parentSampled = parentSampled;
  }

  // missing ctor with traceid, spanid, parentspanid,
}
