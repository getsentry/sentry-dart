// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../utils/internal_logger.dart';
import '../app_start_data.dart';
import 'app_start_trace.dart';

@internal
final class StreamingAppStartTrace implements AppStartTrace {
  final Hub _hub;
  final AppStartData _data;
  final IdleRecordingSentrySpanV2 _root;
  final RecordingSentrySpanV2 _firstFrameBarrier;
  final String Function() _startScreenNameProvider;

  late final SdkLifecycleCallback<OnProcessSpan> _processCallback;
  late final SdkLifecycleCallback<OnSpanStartV2> _onSpanStartCallback;
  late final SdkLifecycleCallback<OnSpanEndV2> _onSpanEndCallback;
  RecordingSentrySpanV2? _extendedSpan;
  final _extendedDescendants = <SpanId, RecordingSentrySpanV2>{};
  Future<void>? _extensionCompletion;
  DateTime? _extensionEndTimestamp;
  bool _extensionFinalizing = false;
  DateTime? _endTimestamp;
  bool _completed = false;
  bool _closed = false;

  StreamingAppStartTrace._({
    required Hub hub,
    required AppStartData data,
    required IdleRecordingSentrySpanV2 root,
    required RecordingSentrySpanV2 firstFrameBarrier,
    required String Function() startScreenNameProvider,
  })  : _hub = hub,
        _data = data,
        _root = root,
        _firstFrameBarrier = firstFrameBarrier,
        _startScreenNameProvider = startScreenNameProvider {
    _onSpanStartCallback = _onSpanStart;
    _onSpanEndCallback = _onSpanEnd;
  }

  static StreamingAppStartTrace? tryCreate({
    required Hub hub,
    required AppStartData data,
    required String Function() startScreenNameProvider,
  }) {
    IdleRecordingSentrySpanV2? createdRoot;
    final createdChildren = <RecordingSentrySpanV2>[];
    try {
      final root = hub.startIdleSpan(
        standaloneAppStartRootName,
        bindToHub: false,
        idleTimeout: standaloneAppStartIdleTimeout,
        finalTimeout: standaloneAppStartFinalTimeout,
        trimIdleSpanEndTimestamp: true,
        startTimestamp: data.processStartTimestamp,
        attributes: {
          SemanticAttributesConstants.sentryOp: SentryAttribute.string(
            SentrySpanOperations.appStart,
          ),
          SemanticAttributesConstants.sentryOrigin: SentryAttribute.string(
            SentryTraceOrigins.autoAppStart,
          ),
          SemanticAttributesConstants.appVitalsStartType:
              SentryAttribute.string(data.type.name),
        },
      );
      if (root is! IdleRecordingSentrySpanV2) return null;
      createdRoot = root;

      final firstFrameBarrier = hub.startInactiveSpan(
        appStartFirstFrameRenderDescription,
        parentSpan: root,
        startTimestamp: data.sentrySetupTimestamp,
        attributes: _childAttributes(
          data,
          SentrySpanOperations.appStartFirstFrameRender,
        ),
      );
      if (firstFrameBarrier is! RecordingSentrySpanV2) {
        _finishProvisionalSpans(root: createdRoot);
        return null;
      }
      createdChildren.add(firstFrameBarrier);

      final trace = StreamingAppStartTrace._(
        hub: hub,
        data: data,
        root: root,
        firstFrameBarrier: firstFrameBarrier,
        startScreenNameProvider: startScreenNameProvider,
      );
      trace._processCallback = trace._processSpan;
      for (final phase in data.phases) {
        final child = hub.startInactiveSpan(
          phase.description,
          parentSpan: root,
          startTimestamp: phase.startTimestamp,
          attributes: _childAttributes(data, phase.operation),
        );
        if (child is RecordingSentrySpanV2) {
          createdChildren.add(child);
        }
        child.end(endTimestamp: phase.endTimestamp);
      }
      hub.options.lifecycleRegistry.registerCallback<OnProcessSpan>(
        trace._processCallback,
      );
      return trace;
    } catch (error, stackTrace) {
      _finishProvisionalSpans(
        root: createdRoot,
        children: createdChildren,
      );
      internalLogger.error(
        'Failed to create streaming standalone app start',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  static Map<String, SentryAttribute> _childAttributes(
    AppStartData data,
    String operation,
  ) =>
      {
        SemanticAttributesConstants.sentryOp: SentryAttribute.string(operation),
        SemanticAttributesConstants.sentryOrigin: SentryAttribute.string(
          SentryTraceOrigins.autoAppStart,
        ),
        SemanticAttributesConstants.appVitalsStartType: SentryAttribute.string(
          data.type.name,
        ),
      };

  static void _finishProvisionalSpans({
    IdleRecordingSentrySpanV2? root,
    Iterable<RecordingSentrySpanV2> children = const [],
  }) {
    for (final child in children) {
      if (!child.isEnded) {
        child.end();
      }
    }
    root?.end();
  }

  @override
  bool tryExtend(DateTime startTimestamp) {
    if (_closed ||
        _completed ||
        _firstFrameBarrier.isEnded ||
        _extendedSpan != null) {
      return false;
    }

    final extension = _hub.startInactiveSpan(
      standaloneExtendedAppStartName,
      parentSpan: _root,
      startTimestamp: startTimestamp.toUtc(),
      attributes: {
        SemanticAttributesConstants.sentryOp: SentryAttribute.string(
          SentrySpanOperations.appStartExtended,
        ),
        SemanticAttributesConstants.sentryOrigin: SentryAttribute.string(
          SentryTraceOrigins.autoAppStart,
        ),
      },
    );
    if (extension is! RecordingSentrySpanV2) {
      return false;
    }

    _extendedSpan = extension;
    _hub.options.lifecycleRegistry
      ..registerCallback<OnSpanStartV2>(
        _onSpanStartCallback,
        prepend: true,
      )
      ..registerCallback<OnSpanEndV2>(
        _onSpanEndCallback,
        prepend: true,
      );
    return true;
  }

  @override
  ISentrySpan get extendedSpan => NoOpSentrySpan();

  @override
  SentrySpanV2 get extendedSpanV2 {
    final extension = _extendedSpan;
    return extension == null || extension.isEnded
        ? const NoOpSentrySpanV2()
        : extension;
  }

  @override
  Future<void> finishExtended(DateTime endTimestamp) {
    final extension = _extendedSpan;
    if (_closed || _completed || extension == null) {
      return Future<void>.value();
    }

    final completion = _extensionCompletion;
    if (completion != null) {
      return completion;
    }

    final future = _finishExtension(endTimestamp.toUtc());
    _extensionCompletion = future;
    return future;
  }

  @override
  void recordFirstFrame(DateTime endTimestamp) {
    if (_closed || _completed) return;
    _firstFrameBarrier.end(endTimestamp: endTimestamp.toUtc());
  }

  @override
  void finish(DateTime endTimestamp) {
    if (_closed || _completed || _endTimestamp != null) return;
    _endTimestamp = endTimestamp.toUtc();
  }

  void _processSpan(OnProcessSpan event) {
    if (!identical(event.span, _root) || _completed) return;
    try {
      _root.setAttribute(
        SemanticAttributesConstants.appVitalsStartType,
        SentryAttribute.string(_data.type.name),
      );
      _root.setAttribute(
        SemanticAttributesConstants.appVitalsStartScreen,
        SentryAttribute.string(_startScreenNameProvider()),
      );
      _root.setAttribute(
        SemanticAttributesConstants.sentrySegmentName,
        SentryAttribute.string(standaloneAppStartRootName),
      );

      final endTimestamp = _endTimestamp;
      final extensionCompleted =
          _extendedSpan == null || _extensionEndTimestamp != null;
      if (endTimestamp != null &&
          extensionCompleted &&
          !_rootDeadlineExceeded) {
        final extensionEndTimestamp = _extensionEndTimestamp;
        final measurementEnd = extensionEndTimestamp != null &&
                extensionEndTimestamp.isAfter(endTimestamp)
            ? extensionEndTimestamp
            : endTimestamp;
        final duration =
            _data.durationUntil(measurementEnd).inMilliseconds.toDouble();
        final value = SentryAttribute.double(duration);
        _root.setAttribute(
          SemanticAttributesConstants.appVitalsStartValue,
          value,
        );
        _root.setAttribute(
          _data.type == AppStartType.cold
              ? SemanticAttributesConstants.appVitalsStartColdValue
              : SemanticAttributesConstants.appVitalsStartWarmValue,
          value,
        );
      }
    } catch (error, stackTrace) {
      internalLogger.error(
        'Failed to enrich streaming standalone app start',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _completed = true;
      _hub.options.lifecycleRegistry.removeCallback<OnProcessSpan>(
        _processCallback,
      );
    }
  }

  @override
  Future<void> close() async {
    if (_closed || _completed) return;
    _closed = true;
    try {
      final completion = _extensionCompletion;
      if (completion != null) {
        await completion;
      } else {
        final extension = _extendedSpan;
        if (extension != null && _extensionEndTimestamp == null) {
          await _finishExtension(
              extension.endTimestamp ?? _hub.options.clock());
        }
      }
    } finally {
      _extendedDescendants.clear();
      _root.end();
    }
  }

  void _onSpanStart(OnSpanStartV2 event) {
    final extension = _extendedSpan;
    final span = event.span;
    if (extension == null ||
        span is! RecordingSentrySpanV2 ||
        identical(span, extension)) {
      return;
    }

    if (_isExtensionDescendant(span, extension)) {
      _extendedDescendants[span.spanId] = span;
    }
  }

  Future<void> _onSpanEnd(OnSpanEndV2 event) async {
    final extension = _extendedSpan;
    if (extension == null ||
        !identical(event.span, extension) ||
        _extensionFinalizing) {
      return;
    }

    final endTimestamp = extension.endTimestamp;
    if (endTimestamp == null) return;

    if (_rootDeadlineExceeded) {
      _extensionFinalizing = true;
      extension.status = SentrySpanStatusV2.error;
      extension.setAttribute(
        SemanticAttributesConstants.sentryStatusMessage,
        SentryAttribute.string(SentrySpanStatusMessages.deadlineExceeded),
      );
      _extendedDescendants.clear();
      _removeExtensionCallbacks();
      return;
    }

    extension.status = SentrySpanStatusV2.ok;
    final future = _finishExtension(endTimestamp);
    _extensionCompletion = future;
    await future;
  }

  Future<void> _finishExtension(DateTime endTimestamp) async {
    if (_extensionFinalizing) return;
    _extensionFinalizing = true;
    final timestamp = endTimestamp.toUtc();
    _extensionEndTimestamp ??= timestamp;
    try {
      final extension = _extendedSpan;
      if (extension == null) return;

      while (true) {
        final openDescendants =
            _extendedDescendants.values.where((span) => !span.isEnded).toList()
              ..sort(
                (left, right) =>
                    _extensionDepth(right).compareTo(_extensionDepth(left)),
              );
        if (openDescendants.isEmpty) break;

        for (final descendant in openDescendants) {
          descendant.status = SentrySpanStatusV2.ok;
          descendant.setAttribute(
            SemanticAttributesConstants.sentryStatusMessage,
            SentryAttribute.string(SentrySpanStatusMessages.cancelled),
          );
          descendant.end(endTimestamp: timestamp);
        }
        await Future<void>.delayed(Duration.zero);
      }

      extension.status = SentrySpanStatusV2.ok;
      if (!extension.isEnded) {
        extension.end(endTimestamp: timestamp);
      }
    } finally {
      _extendedDescendants.clear();
      _removeExtensionCallbacks();
    }
  }

  bool _isExtensionDescendant(
    RecordingSentrySpanV2 span,
    RecordingSentrySpanV2 extension,
  ) {
    RecordingSentrySpanV2? current = span.parentSpan;
    while (current != null) {
      if (identical(current, extension)) return true;
      current = current.parentSpan;
    }
    return false;
  }

  int _extensionDepth(RecordingSentrySpanV2 span) {
    var depth = 0;
    RecordingSentrySpanV2? current = span.parentSpan;
    final extension = _extendedSpan;
    while (current != null && !identical(current, extension)) {
      depth++;
      current = current.parentSpan;
    }
    return depth;
  }

  bool get _rootDeadlineExceeded =>
      _root.status == SentrySpanStatusV2.error &&
      _root.attributes[SemanticAttributesConstants.sentryStatusMessage]
              ?.value ==
          SentrySpanStatusMessages.deadlineExceeded;

  void _removeExtensionCallbacks() {
    _hub.options.lifecycleRegistry
      ..removeCallback<OnSpanStartV2>(_onSpanStartCallback)
      ..removeCallback<OnSpanEndV2>(_onSpanEndCallback);
  }
}
