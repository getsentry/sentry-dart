// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../utils/internal_logger.dart';
import '../app_start_timing.dart';
import 'app_start_trace.dart';
import 'app_start_vitals.dart';

@internal
final class StreamingAppStartTrace implements AppStartTrace {
  final Hub _hub;
  final AppStartTiming _timing;
  final IdleRecordingSentrySpanV2 _root;

  final SentrySpanV2 _sentryInitSpan;

  final String Function() _startScreenNameProvider;
  final void Function()? _onCompleted;

  final _StreamingAppStartExtensionLifecycle _extensionLifecycle;
  DateTime? _endTimestamp;
  bool _initCompleted = false;
  bool _firstFrameObserved = false;
  AppStartTraceState _state = AppStartTraceState.open;

  StreamingAppStartTrace._({
    required Hub hub,
    required AppStartTiming timing,
    required IdleRecordingSentrySpanV2 root,
    required this._sentryInitSpan,
    required this._startScreenNameProvider,
    required this._onCompleted,
  }) : _hub = hub,
       _timing = timing,
       _root = root,
       _extensionLifecycle = _StreamingAppStartExtensionLifecycle(
         hub: hub,
         root: root,
         timing: timing,
       );

  /// Opens the standalone root and its breakdown children.
  ///
  /// Returns `null` when the root is not recorded or creating a child throws.
  /// Filtered children do not suppress the root measurement. Anything already
  /// created is flushed on failure, so no span outlives a failed creation.
  ///
  /// [onCompleted] fires once the root has reported and the trace can no
  /// longer be extended, so the owner can stop holding on to it.
  static StreamingAppStartTrace? tryCreate({
    required Hub hub,
    required AppStartTiming timing,
    required String Function() startScreenNameProvider,
    void Function()? onCompleted,
  }) {
    // Held outside the try so a partially built trace can still be flushed.
    IdleRecordingSentrySpanV2? root;
    try {
      final createdRoot = hub.startIdleSpan(
        standaloneAppStartRootName,
        bindToHub: false,
        idleTimeout: standaloneAppStartIdleTimeout,
        finalTimeout: standaloneAppStartFinalTimeout,
        trimIdleSpanEndTimestamp: true,
        startTimestamp: timing.processStartTimestamp,
        attributes: {
          SemanticAttributesConstants.sentryOp: SentryAttribute.string(
            SentrySpanOperations.appStart,
          ),
          SemanticAttributesConstants.sentryOrigin: SentryAttribute.string(
            SentryTraceOrigins.autoAppStart,
          ),
          SemanticAttributesConstants.appVitalsStartType:
              SentryAttribute.string(timing.type.name),
          SemanticAttributesConstants.appVitalsStartScreen:
              SentryAttribute.string(startScreenNameProvider()),
        },
      );
      if (createdRoot is! IdleRecordingSentrySpanV2) return null;
      root = createdRoot;
      root.pauseIdleTimeout();

      final sentryInitSpan = hub.startInactiveSpan(
        'Sentry Initialization',
        parentSpan: root,
        startTimestamp: timing.sentrySetupTimestamp,
        attributes: _childAttributes(
          timing,
          SentrySpanOperations.appStartSentryInit,
        ),
      );

      final trace = StreamingAppStartTrace._(
        hub: hub,
        timing: timing,
        root: root,
        sentryInitSpan: sentryInitSpan,
        startScreenNameProvider: startScreenNameProvider,
        onCompleted: onCompleted,
      );
      hub.options.lifecycleRegistry.registerCallback<OnProcessSpan>(
        trace._processSpan,
      );
      for (final interval in timing.intervals) {
        trace._recordInterval(interval);
      }
      return trace;
    } catch (error, stackTrace) {
      internalLogger.error(
        'Failed to create streaming standalone app start',
        error: error,
        stackTrace: stackTrace,
      );
      return root == null ? null : _abort(root);
    }
  }

  static Map<String, SentryAttribute> _childAttributes(
    AppStartTiming timing,
    String operation,
  ) => {
    SemanticAttributesConstants.sentryOp: SentryAttribute.string(operation),
    SemanticAttributesConstants.sentryOrigin: SentryAttribute.string(
      SentryTraceOrigins.autoAppStart,
    ),
    SemanticAttributesConstants.appVitalsStartType: SentryAttribute.string(
      timing.type.name,
    ),
  };

  /// Flushes everything created so far and reports no trace.
  ///
  /// Ending the root force-ends the children it tracks, so a partially built
  /// trace leaves nothing open. The root learns about a child through the
  /// `OnSpanStartV2` dispatch, which reaches it synchronously only while no
  /// earlier-registered listener returns a future — see the abort tests.
  static StreamingAppStartTrace? _abort(IdleRecordingSentrySpanV2 root) {
    root.end();
    return null;
  }

  @override
  bool tryExtend(DateTime startTimestamp) {
    // No `_finalizing` guard like the static trace's. The deadline is owned by
    // the idle root here, which force-ends its descendants synchronously, so
    // there is no window where the trace is winding down but not yet terminal.
    if (_state.isTerminal) {
      logAppStartExtensionRefusal('the app start already ended');
      return false;
    }
    if (_firstFrameObserved) {
      logAppStartExtensionRefusal('the first frame already rendered');
      return false;
    }

    return _extensionLifecycle.tryStart(startTimestamp);
  }

  @override
  ISentrySpan? get extendedSpan => null;

  @override
  SentrySpanV2? get extendedSpanV2 => _extensionLifecycle.activeSpan;

  @override
  Future<void> finishExtended(DateTime endTimestamp) {
    if (_state.isTerminal) {
      logAppStartExtensionFinishRefusal('the app start already ended');
      return Future<void>.value();
    }

    return _extensionLifecycle.finish(endTimestamp);
  }

  @override
  void recordInitEnd(DateTime endTimestamp) {
    if (_state.isTerminal || _initCompleted) return;
    _initCompleted = true;
    _sentryInitSpan.end(endTimestamp: endTimestamp.toUtc());
    if (_firstFrameObserved) {
      _root.resumeIdleTimeout(minimumEndTimestamp: _endTimestamp);
    }
  }

  @override
  void recordFirstFrame(
    AppStartRecordedInterval? rasterInterval, {
    List<AppStartRecordedInterval> frameworkIntervals = const [],
  }) {
    if (_state.isTerminal || _firstFrameObserved) return;
    _firstFrameObserved = true;
    _endTimestamp = rasterInterval?.endTimestamp;
    _root.setAttribute(
      SemanticAttributesConstants.appVitalsStartScreen,
      SentryAttribute.string(_startScreenNameProvider()),
    );

    if (rasterInterval != null) {
      for (final interval in frameworkIntervals) {
        _recordInterval(interval);
      }
      _recordInterval(rasterInterval);
    }
    if (_initCompleted) {
      _root.resumeIdleTimeout(minimumEndTimestamp: _endTimestamp);
    }
  }

  /// Emits a completed interval directly under the startup root.
  void _recordInterval(AppStartRecordedInterval interval) {
    final span = _hub.startInactiveSpan(
      interval.description,
      parentSpan: _root,
      startTimestamp: interval.startTimestamp,
      attributes: _childAttributes(_timing, interval.operation),
    );
    if (span is! RecordingSentrySpanV2) return;
    // The callback isolate does not identify the engine's raster thread.
    if (interval.operation == SentrySpanOperations.appStartFrameRaster) {
      span.removeAttribute(SemanticAttributesConstants.threadName);
      span.removeAttribute(SemanticAttributesConstants.threadId);
    }
    interval.data.forEach(
      (key, value) => span.setAttribute(key, SentryAttribute.bool(value)),
    );
    span.end(endTimestamp: interval.endTimestamp);
  }

  void _processSpan(OnProcessSpan event) {
    _copyStartVitalsFromSegment(event.span);

    if (!identical(event.span, _root) ||
        _state == AppStartTraceState.completed) {
      return;
    }
    try {
      final vitals = AppStartVitals.resolve(
        timing: _timing,
        screen: _startScreenNameProvider(),
        firstFrameTimestamp: _endTimestamp,
        extensionEndTimestamp: _extensionLifecycle.measurementEnd,
      );

      _root.setAttribute(
        SemanticAttributesConstants.appVitalsStartScreen,
        SentryAttribute.string(vitals.screen),
      );
      _root.setAttribute(
        SemanticAttributesConstants.sentrySegmentName,
        SentryAttribute.string(standaloneAppStartRootName),
      );

      final duration = vitals.duration;
      if (duration != null) {
        final value = SentryAttribute.double(
          duration.inMilliseconds.toDouble(),
        );
        _root.setAttribute(
          ProposedSemanticAttributes.appVitalsStartValue,
          value,
        );
        _root.setAttribute(vitals.durationAttributeKey, value);
      }
    } catch (error, stackTrace) {
      internalLogger.error(
        'Failed to enrich streaming standalone app start',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _state = AppStartTraceState.completed;
      _hub.options.lifecycleRegistry.removeCallback<OnProcessSpan>(
        _processSpan,
      );
    }
    _onCompleted?.call();
  }

  @override
  Future<void> close() async {
    if (_state.isTerminal) return;
    _state = AppStartTraceState.closed;
    try {
      await _extensionLifecycle.close();
    } finally {
      _root.end();
    }
  }

  void _copyStartVitalsFromSegment(RecordingSentrySpanV2 span) {
    final segment = span.segmentSpan;
    if (identical(span, segment)) return;
    if (segment.attributes[SemanticAttributesConstants.sentryOp]?.value !=
        SentrySpanOperations.appStart) {
      return;
    }
    final attributes = segment.attributes;
    final screen = attributes[SemanticAttributesConstants.appVitalsStartScreen];
    if (screen != null) {
      span.setAttribute(
        SemanticAttributesConstants.appVitalsStartScreen,
        screen,
      );
    }
    final type = attributes[SemanticAttributesConstants.appVitalsStartType];
    if (type != null) {
      span.setAttribute(SemanticAttributesConstants.appVitalsStartType, type);
    }
  }
}

/// Owns the streaming extension. The idle root ends it synchronously at the
/// deadline, so no pending-finish wait is needed as in the static lifecycle.
final class _StreamingAppStartExtensionLifecycle {
  final Hub _hub;
  final IdleRecordingSentrySpanV2 _root;
  final AppStartTiming _timing;

  late final SdkLifecycleCallback<OnSpanEndV2> _spanEndCallback;
  RecordingSentrySpanV2? _span;
  Future<void>? _finishFuture;
  DateTime? _endTimestamp;
  bool _forceEnded = false;
  bool _closed = false;

  _StreamingAppStartExtensionLifecycle({
    required this._hub,
    required this._root,
    required this._timing,
  }) {
    _spanEndCallback = _handleSpanEnd;
  }

  bool tryStart(DateTime startTimestamp) {
    if (_closed) {
      logAppStartExtensionRefusal('the app start already ended');
      return false;
    }
    if (_span != null) {
      logAppStartExtensionRefusal('it is already extended');
      return false;
    }

    final span = _hub.startInactiveSpan(
      standaloneAppStartExtensionName,
      parentSpan: _root,
      startTimestamp: startTimestamp.toUtc(),
      attributes: StreamingAppStartTrace._childAttributes(
        _timing,
        SentrySpanOperations.appStartExtended,
      ),
    );
    if (span is! RecordingSentrySpanV2) {
      logAppStartExtensionRefusal('the extension span was not recorded');
      return false;
    }

    _span = span;
    _hub.options.lifecycleRegistry.registerCallback<OnSpanEndV2>(
      _spanEndCallback,
    );
    return true;
  }

  SentrySpanV2? get activeSpan {
    final span = _span;
    return span == null || span.isEnded ? null : span;
  }

  /// The endpoint the extension contributes to the app-start measurement.
  ///
  /// `null` when it contributes none: it never started, it is still running, or
  /// it was force-ended — by the root's deadline or by SDK close — which ends
  /// the span at the teardown rather than at anything the extension reached.
  DateTime? get measurementEnd => _forceEnded ? null : _endTimestamp;

  Future<void> finish(DateTime endTimestamp) {
    if (_closed) {
      logAppStartExtensionFinishRefusal('the app start already ended');
      return Future<void>.value();
    }
    if (_span == null) {
      logAppStartExtensionFinishRefusal('it was never extended');
      return Future<void>.value();
    }
    return _finishFuture ??= _finishSpan(endTimestamp: endTimestamp.toUtc());
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;

    final finishFuture = _finishFuture;
    if (finishFuture != null) {
      await finishFuture;
      return;
    }

    if (_span != null && _endTimestamp == null) {
      await _finishSpan();
    }
  }

  // Handle callers ending the span directly instead of using
  // finishExtendedAppStart().
  void _handleSpanEnd(OnSpanEndV2 event) {
    final span = _span;
    if (span == null || !identical(event.span, span) || _endTimestamp != null) {
      return;
    }

    final endTimestamp = span.endTimestamp;
    if (endTimestamp == null) return;

    if (_root.deadlineExceeded) {
      span.status = SentrySpanStatusV2.error;
      span.setAttribute(
        SemanticAttributesConstants.sentryStatusMessage,
        SentryAttribute.string(SentrySpanStatusMessages.deadlineExceeded),
      );
      _forceEnded = true;
    } else {
      span.status = SentrySpanStatusV2.ok;
    }

    _endTimestamp = endTimestamp;
    _removeSpanEndCallback();
  }

  /// Settles the extension, ending the span unless the caller already did.
  ///
  /// A span the caller ended keeps its own endpoint; [endTimestamp] applies to
  /// one that is still running, and falls back to now when omitted.
  ///
  /// Unlike the static lifecycle, this always settles on success: the root
  /// force-ends the extension synchronously when it hits its deadline, and
  /// [_handleSpanEnd] latches [_endTimestamp] with the deadline outcome before
  /// anything here can run, so a deadline never reaches this path.
  Future<void> _finishSpan({DateTime? endTimestamp}) async {
    if (_endTimestamp != null) return;
    final span = _span;
    if (span == null) return;

    try {
      final timestamp =
          (span.endTimestamp ?? endTimestamp ?? _hub.options.clock()).toUtc();
      // Only [close] gets here already closed, and the extension it ends never
      // reached this endpoint on its own.
      _forceEnded = _closed;
      _endTimestamp = timestamp;

      span.status = SentrySpanStatusV2.ok;
      if (!span.isEnded) {
        span.end(endTimestamp: timestamp);
      }
    } catch (error, stackTrace) {
      internalLogger.error(
        'Failed to finish streaming extended app start',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _removeSpanEndCallback();
    }
  }

  void _removeSpanEndCallback() {
    _hub.options.lifecycleRegistry.removeCallback<OnSpanEndV2>(
      _spanEndCallback,
    );
  }
}
