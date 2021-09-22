import 'package:meta/meta.dart';

import 'tracing.dart';
import 'sentry_options.dart';

/// Context used by [TracesSamplerCallback] to determine if transaction
/// is going to be sampled.
@immutable
class SentrySamplingContext {
  final SentryTransactionContext _transactionContext;
  final Map<String, dynamic> _customSamplingContext;

  SentrySamplingContext(this._transactionContext, this._customSamplingContext);

  /// The Transaction context
  SentryTransactionContext get transactionContext => _transactionContext;

  /// The given sampling context
  Map<String, dynamic> get customSamplingContext =>
      Map.unmodifiable(_customSamplingContext);
}
