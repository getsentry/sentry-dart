import '../sentry.dart';
import 'tracing.dart';

class SentryTracer extends SentrySpan {
  Hub _hub;
  SentryTransactionContext _transactionContext;

  // missing waitForChildren

  String? name;
  @override
  late SentrySpanContext context;
  DateTime? timestamp;
  DateTime? startTimestamp;
  late bool isFinished;

  // find out how to pass its own instance to super
  SentryTracer(this._hub, this._transactionContext)
      : super(_transactionContext);
}
