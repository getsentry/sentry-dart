// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../utils/internal_logger.dart';
import 'app_start_info.dart';
import 'native_app_start_handler.dart';
import 'native_app_start_handler_v2.dart';

/// Owns the app start transaction across both trace lifecycles.
///
/// All app start data flows through [track], regardless of source. Depending
/// on [SentryFlutterOptions.enableStandaloneAppStartTracing] the payload is
/// attached to the first `ui.load` root or emitted as a standalone
/// `app.start` transaction; the first `ui.load` root is created and backdated
/// either way.
@internal
class AppStartTracker {
  final _handler = NativeAppStartHandler();
  final _handlerV2 = NativeAppStartHandlerV2();

  SentryTransactionContext? _staticContext;
  bool _tracked = false;

  /// Prepares per-lifecycle state so spans created before the app start data
  /// arrives (e.g. TTFD, user spans in initState) can reference the root.
  void prepare(Hub hub, SentryFlutterOptions options) {
    switch (options.traceLifecycle) {
      case SentryTraceLifecycle.static:
        final context = SentryTransactionContext(
          'root /',
          SentrySpanOperations.uiLoad,
          origin: SentryTraceOrigins.autoUiTimeToDisplay,
        );
        options.timeToDisplayTracker.transactionId = context.spanId;
        _staticContext = context;
      case SentryTraceLifecycle.stream:
        options.timeToDisplayTrackerV2.prepareAppStart();
    }
  }

  /// Tracks the app start described by [appStartInfo]. Only the first call
  /// has an effect, so at most one app start transaction is emitted.
  Future<void> track(
    Hub hub,
    SentryFlutterOptions options,
    AppStartInfo appStartInfo,
  ) async {
    if (_tracked) {
      internalLogger.debug('App start already tracked, ignoring call.');
      return;
    }
    _tracked = true;

    final standalone = options.enableStandaloneAppStartTracing;
    switch (options.traceLifecycle) {
      case SentryTraceLifecycle.stream:
        await _handlerV2.call(
          hub,
          options,
          appStartInfo: appStartInfo,
          standalone: standalone,
        );
      case SentryTraceLifecycle.static:
        final context = _staticContext;
        if (context == null) {
          internalLogger.warning(
            'Skipping app start tracking because no transaction context was '
            'prepared.',
          );
          return;
        }
        await _handler.call(
          hub,
          options,
          context: context,
          appStartInfo: appStartInfo,
          standalone: standalone,
        );
    }
  }

  /// Cancels the prepared root when no app start data will arrive.
  void cancel(SentryFlutterOptions options) {
    if (options.traceLifecycle == SentryTraceLifecycle.stream) {
      options.timeToDisplayTrackerV2.cancelCurrentRoute();
    }
  }
}
