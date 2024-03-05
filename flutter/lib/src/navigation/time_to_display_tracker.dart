// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:meta/meta.dart';
import '../integrations/integrations.dart';

import '../../sentry_flutter.dart';
import '../native/sentry_native.dart';
import 'time_to_initial_display_tracker.dart';

@internal
class TimeToDisplayTracker {
  final SentryNative? _native;
  final TimeToInitialDisplayTracker _ttidTracker;

  // TODO We can use _hub.options to fetch the ttfd flag
  final bool _enableTimeToFullDisplayTracing;

  TimeToDisplayTracker({
    required bool enableTimeToFullDisplayTracing,
    TimeToInitialDisplayTracker? ttidTracker,
  })  : _native = SentryFlutter.native,
        _enableTimeToFullDisplayTracing = enableTimeToFullDisplayTracing,
        _ttidTracker = ttidTracker ?? TimeToInitialDisplayTracker();

  Future<void> startTracking(
      ISentrySpan transaction, String? routeName, Object? arguments) async {
    final startTimestamp = DateTime.now();
    if (routeName == '/') {
      routeName = 'root ("/")';
    }
    final isRootScreen = routeName == 'root ("/")';
    final didFetchAppStart = _native?.didFetchAppStart;

    if (routeName == null) return;

    if (isRootScreen && didFetchAppStart == false) {
      // Dart cannot infer here that routeName is not nullable
      await _trackAppStartTTD(transaction, routeName, arguments);
    } else {
      await _trackRegularRouteTTD(
          transaction, routeName, arguments, startTimestamp);
    }

    clear();
  }

  /// This method listens for the completion of the app's start process via
  /// [AppStartTracker], then:
  /// - Starts a transaction with the app start start timestamp
  /// - Starts TTID and optionally TTFD spans based on the app start start timestamp
  /// - Finishes the TTID span immediately with the app start end timestamp
  ///
  /// We start and immediately finish the TTID span since we cannot mutate the history of spans.
  Future<void> _trackAppStartTTD(
      ISentrySpan transaction, String routeName, Object? arguments) async {
    final appStartInfo = await NativeAppStartIntegration.getAppStartInfo();
    if (appStartInfo == null) return;

    if (_enableTimeToFullDisplayTracing) {
      // TODO: implement TTFD
    }

    await _ttidTracker.trackAppStart(transaction, appStartInfo, routeName);
  }

  /// Starts and finishes Time To Display spans for regular routes meaning routes that are not root.
  Future<void> _trackRegularRouteTTD(ISentrySpan transaction, String routeName,
      Object? arguments, DateTime startTimestamp) async {
    if (_enableTimeToFullDisplayTracing) {
      // TODO: implement TTFD
    }

    await _ttidTracker.trackRegularRoute(
        transaction, startTimestamp, routeName);
  }

  @internal
  Future<void> reportFullyDisplayed() async {
    // TODO: implement TTFD
  }

  void clear() {
    _ttidTracker.clear();
  }
}
