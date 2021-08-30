import 'tracing.dart';

class SentryTransactionContext extends SentrySpanContext {
  late String name;
  late bool parentSampled;

  SentryTransactionContext() : super();
}
