import 'tracing.dart';

class SentrySamplingContext {
  SentryTransactionContext transactionContext;
  Map<String, dynamic> customSamplingContext;

  SentrySamplingContext(this.transactionContext, this.customSamplingContext);
}
