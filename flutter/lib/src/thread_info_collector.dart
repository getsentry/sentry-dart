import 'package:meta/meta.dart';
import '../../sentry_flutter.dart';
import 'isolate_helper.dart';

@internal
class ThreadInfoCollector implements PerformanceContinuousCollector {
  final IsolateHelper _isolateHelper;

  ThreadInfoCollector([IsolateHelper? isolateHelper])
      : _isolateHelper = isolateHelper ?? IsolateHelper();

  @override
  Future<void> onSpanStarted(ISentrySpan span) async {
    // Check if we're in the root isolate first
    if (_isolateHelper.isRootIsolate()) {
      // For root isolate, always set thread name as "main"
      span.setData(SpanDataConvention.threadId, 'main'.hashCode.toString());
      span.setData(SpanDataConvention.threadName, 'main');
      return;
    }

    // For non-root isolates, get thread info dynamically for each span to handle multi-isolate scenarios
    final isolateName = _isolateHelper.getIsolateName();

    // Only set thread info if we have a valid isolate name
    if (isolateName != null && isolateName.isNotEmpty) {
      final threadName = isolateName;
      final threadId = isolateName.hashCode.toString();

      span.setData(SpanDataConvention.threadId, threadId);
      span.setData(SpanDataConvention.threadName, threadName);
    }
  }

  @override
  Future<void> onSpanFinished(ISentrySpan span, DateTime endTimestamp) async {
    // No-op: we only need to set data when span starts
  }

  @override
  void clear() {
    // No-op: thread info doesn't change during execution
  }
}
