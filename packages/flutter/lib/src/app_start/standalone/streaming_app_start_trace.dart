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
  final RecordingSentrySpanV2 _firstFrameRenderSpan;
  final String Function() _startScreenNameProvider;
  final void Function()? _onCompleted;

  final _StreamingAppStartExtensionLifecycle _extensionLifecycle;
  DateTime? _endTimestamp;
  AppStartTraceState _state = AppStartTraceState.open;

  StreamingAppStartTrace._({
    required Hub hub,
    required AppStartTiming timing,
    required IdleRecordingSentrySpanV2 root,
    required this._firstFrameRenderSpan,
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
  /// Returns `null` when the app start must not be reported: a root or
  /// first-frame span the SDK did not record, or a failure while building the
  /// children. Anything already created is flushed, so no span outlives a
  /// failed creation.
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
        },
      );
      if (createdRoot is! IdleRecordingSentrySpanV2) return null;
      root = createdRoot;

      final firstFrameRenderSpan = hub.startInactiveSpan(
        appStartFirstFrameRenderDescription,
        parentSpan: root,
        startTimestamp: timing.sentrySetupTimestamp,
        attributes: _childAttributes(
          timing,
          SentrySpanOperations.appStartFirstFrameRender,
        ),
      );
      if (firstFrameRenderSpan is! RecordingSentrySpanV2) {
        return _abort(root, reason: 'first-frame span is not recording');
      }

      final trace = StreamingAppStartTrace._(
        hub: hub,
        timing: timing,
        root: root,
        firstFrameRenderSpan: firstFrameRenderSpan,
        startScreenNameProvider: startScreenNameProvider,
        onCompleted: onCompleted,
      );
      for (final phase in timing.phases) {
        final child = hub.startInactiveSpan(
          phase.description,
          parentSpan: root,
          startTimestamp: phase.startTimestamp,
          attributes: _childAttributes(timing, phase.kind.operation),
        );
        child.end(endTimestamp: phase.endTimestamp);
      }
      hub.options.lifecycleRegistry.registerCallback<OnProcessSpan>(
        trace._processSpan,
      );
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
  static StreamingAppStartTrace? _abort(
    IdleRecordingSentrySpanV2 root, {
    String? reason,
  }) {
    if (reason != null) {
      internalLogger.info('Skipping streaming standalone app start: $reason');
    }
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
    if (_firstFrameRenderSpan.isEnded) {
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
  void recordFirstFrame(DateTime endTimestamp) {
    if (_state.isTerminal || _endTimestamp != null) return;
    _endTimestamp = endTimestamp.toUtc();
    _firstFrameRenderSpan.end(endTimestamp: _endTimestamp);
  }

  void _processSpan(OnProcessSpan event) {
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
}

/// Owns the single extension span for the streaming lifecycle.
///
/// Mirrors `_StaticAppStartExtensionLifecycle` member for member; see the note
/// there for why the two are not shared. It diverges in two places, both
/// because the idle root here force-ends its descendants synchronously: there
/// is no `waitForPendingFinish`, since no finish can be in flight when the
/// deadline lands, and [_finishSpan] never has to stamp a deadline status.
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
