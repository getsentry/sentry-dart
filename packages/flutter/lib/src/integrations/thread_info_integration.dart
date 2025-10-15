// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
// ignore: implementation_imports
import '../isolate/isolate_helper.dart';

/// Integration for adding thread information to spans.
///
/// This integration registers a lifecycle callback that adds thread/isolate
/// information to spans when they are started.
@internal
class ThreadInfoIntegration implements Integration<SentryFlutterOptions> {
  static const integrationName = 'ThreadInfo';

  final IsolateHelper _isolateHelper;
  Hub? _hub;

  ThreadInfoIntegration([IsolateHelper? isolateHelper])
      : _isolateHelper = isolateHelper ?? IsolateHelper();

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    _hub = hub;

    if (!options.isTracingEnabled()) {
      options.log(
        SentryLevel.info,
        '$integrationName disabled: tracing is not enabled',
      );
      return;
    }

    options.lifecycleRegistry
        .registerCallback<OnSpanStart>(_addThreadInfoToSpan);
    options.lifecycleRegistry
        .registerCallback<OnSpanFinish>(_processSyncSpanOnFinish);

    options.sdk.addIntegration(integrationName);
  }

  @override
  void close() {
    _hub?.options.lifecycleRegistry
        .removeCallback<OnSpanStart>(_addThreadInfoToSpan);
    _hub?.options.lifecycleRegistry
        .removeCallback<OnSpanFinish>(_processSyncSpanOnFinish);
  }

  Future<void> _addThreadInfoToSpan(OnSpanStart event) async {
    final span = event.span;
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

  void _processSyncSpanOnFinish(OnSpanFinish event) {
    final span = event.span;
    if (span is! SentrySpan) {
      return;
    }

    final data = span.data;

    // Check if this is a sync operation
    if (data.containsKey('sync')) {
      // Check if we're on the main isolate by looking at thread name
      if (data['sync'] == true &&
          data[SpanDataConvention.threadName] == 'main') {
        span.setData(SpanDataConvention.blockedMainThread, true);
      }

      // Always remove the sync flag
      span.removeData('sync');
    }
  }
}
