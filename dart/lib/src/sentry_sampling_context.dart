import 'package:meta/meta.dart';

import 'tracing.dart';

@immutable
class SentrySamplingContext {
  final SentryTransactionContext _transactionContext;
  final Map<String, dynamic> _customSamplingContext;

  SentrySamplingContext(this._transactionContext, this._customSamplingContext);

  SentryTransactionContext get transactionContext => _transactionContext;

  Map<String, dynamic> get customSamplingContext => _customSamplingContext;
}
