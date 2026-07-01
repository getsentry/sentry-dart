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

    switch (options.traceLifecycle) {
      case SentryTraceLifecycle.static:
        options.lifecycleRegistry
            .registerCallback<OnSpanStart>(_addThreadInfoToSpan);
        options.lifecycleRegistry
            .registerCallback<OnSpanFinish>(_processSyncSpanOnFinish);
      case SentryTraceLifecycle.stream:
        options.lifecycleRegistry
            .registerCallback<OnSpanStartV2>(_addThreadInfoToSpanV2);
        options.lifecycleRegistry
            .registerCallback<OnProcessSpan>(_processSyncSpanOnProcess);
    }

    options.sdk.addIntegration(integrationName);
  }

  @override
  void close() {
    final options = _hub?.options;
    if (options == null) {
      return;
    }
    switch (options.traceLifecycle) {
      case SentryTraceLifecycle.static:
        options.lifecycleRegistry
            .removeCallback<OnSpanStart>(_addThreadInfoToSpan);
        options.lifecycleRegistry
            .removeCallback<OnSpanFinish>(_processSyncSpanOnFinish);
      case SentryTraceLifecycle.stream:
        options.lifecycleRegistry
            .removeCallback<OnSpanStartV2>(_addThreadInfoToSpanV2);
        options.lifecycleRegistry
            .removeCallback<OnProcessSpan>(_processSyncSpanOnProcess);
    }
  }

  Future<void> _addThreadInfoToSpan(OnSpanStart event) async {
    final span = event.span;
    if (_isolateHelper.isRootIsolate()) {
      span.setData(
          SemanticAttributesConstants.threadId, 'main'.hashCode.toString());
      span.setData(SemanticAttributesConstants.threadName, 'main');
      return;
    }

    // Resolve per span so multiple isolates are handled correctly.
    final isolateName = _isolateHelper.getIsolateName();
    if (isolateName != null && isolateName.isNotEmpty) {
      span.setData(SemanticAttributesConstants.threadId,
          isolateName.hashCode.toString());
      span.setData(SemanticAttributesConstants.threadName, isolateName);
    }
  }

  void _processSyncSpanOnFinish(OnSpanFinish event) {
    final span = event.span;
    if (span is! SentrySpan || !span.isSynchronous) {
      return;
    }

    if (span.data[SemanticAttributesConstants.threadName] == 'main') {
      span.setData(SemanticAttributesConstants.blockedMainThread, true);
    }
    span.clearSynchronous();
  }

  Future<void> _addThreadInfoToSpanV2(OnSpanStartV2 event) async {
    final span = event.span;
    if (_isolateHelper.isRootIsolate()) {
      span.setAttribute(SemanticAttributesConstants.threadId,
          SentryAttribute.string('main'.hashCode.toString()));
      span.setAttribute(SemanticAttributesConstants.threadName,
          SentryAttribute.string('main'));
      return;
    }

    // Resolve per span so multiple isolates are handled correctly.
    final isolateName = _isolateHelper.getIsolateName();
    if (isolateName != null && isolateName.isNotEmpty) {
      span.setAttribute(SemanticAttributesConstants.threadId,
          SentryAttribute.string(isolateName.hashCode.toString()));
      span.setAttribute(SemanticAttributesConstants.threadName,
          SentryAttribute.string(isolateName));
    }
  }

  void _processSyncSpanOnProcess(OnProcessSpan event) {
    final span = event.span;
    if (!span.isSynchronous) {
      return;
    }

    if (span.attributes[SemanticAttributesConstants.threadName]?.value ==
        'main') {
      span.setAttribute(SemanticAttributesConstants.blockedMainThread,
          SentryAttribute.bool(true));
    }
    span.clearSynchronous();
  }
}
