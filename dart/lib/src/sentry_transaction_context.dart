// import 'package:meta/meta.dart';

import 'tracing.dart';

// @immutable
// cannot be immutable because of sampled
// to set sampled requires running the SentrySamplingContext
// and the SentrySamplingContext requires the instantiated SentryTransactionContext
class SentryTransactionContext extends SentrySpanContext {
  final String name;
  final bool? parentSampled;
  bool? sampled;

  SentryTransactionContext(
    this.name,
    String operation, {
    String? description,
    this.sampled,
    this.parentSampled,
  }) : super(
          operation: operation,
          description: description,
        );
}
