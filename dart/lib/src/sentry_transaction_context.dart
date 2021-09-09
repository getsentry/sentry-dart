import 'tracing.dart';

class SentryTransactionContext extends SentrySpanContext {
  final String _name;
  bool? _parentSampled;

  SentryTransactionContext(
    this._name,
    String operation, {
    String? description,
    bool? sampled,
    bool? parentSampled,
  }) : super(
          operation: operation,
          sampled: sampled,
          description: description,
        ) {
    _parentSampled = parentSampled;
  }

  bool? get parentSampled => _parentSampled;

  String get name => _name;
}
