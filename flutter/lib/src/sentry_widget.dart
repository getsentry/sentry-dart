import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import '../sentry_flutter.dart';

/// This widget serves as a wrapper to include Sentry widgets such
/// as [SentryScreenshotWidget] and [SentryUserInteractionWidget].
class SentryWidget extends StatefulWidget {
  final Widget child;

  const SentryWidget({super.key, required this.child});

  @override
  _SentryWidgetState createState() => _SentryWidgetState();
}

class _SentryWidgetState extends State<SentryWidget> {
  @override
  Widget build(BuildContext context) {
    Widget content = widget.child;
    content = SentryScreenshotWidget(child: content);
    content = SentryUserInteractionWidget(child: content);
    return content;
  }
}

class SentryDisplayWidget extends StatefulWidget {
  final Widget child;

  const SentryDisplayWidget({super.key, required this.child});

  @override
  _SentryDisplayWidgetState createState() => _SentryDisplayWidgetState();
}

class _SentryDisplayWidgetState extends State<SentryDisplayWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SentryFlutter.reportInitiallyDisplayed(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class SentryDisplayTracker {
  static final SentryDisplayTracker _instance =
      SentryDisplayTracker._internal();

  factory SentryDisplayTracker() {
    return _instance;
  }

  SentryDisplayTracker._internal();

  final Map<String, bool> _manualReportReceived = {};
  final Map<String, Timer> _timers = {};
  final Map<String, Completer<StrategyDecision>> _completers = {}; // Track completers

  void startTimeout(String routeName, Function onTimeout) {
    _timers[routeName]?.cancel(); // Cancel any existing timer
    _timers[routeName] = Timer(Duration(seconds: 1), () {
      // Don't send if we already received a manual report or if we're on the root route e.g App start.
      if (!(_manualReportReceived[routeName] ?? false)) {
        onTimeout();
      }
    });
  }

  Future<StrategyDecision> decideStrategyWithTimeout(String routeName) {
    var completer = Completer<StrategyDecision>();

    _timers[routeName]?.cancel();
    _timers[routeName] = Timer(Duration(seconds: 1), () {
      if (_manualReportReceived[routeName] == true) {
        completer.complete(StrategyDecision.manual);
      } else {
        completer.complete(StrategyDecision.approximation);
      }
    });

    return completer.future;
  }

  Future<StrategyDecision> decideStrategyWithTimeout2(String routeName) {
    // Ensure initialization of a completer for the given route name.
    if (!_completers.containsKey(routeName) || _completers[routeName]!.isCompleted) {
      _completers[routeName] = Completer<StrategyDecision>();
    }
    var completer = _completers[routeName]!;

    // Start or reset the timer only if a manual report has not been received.
    if (!_manualReportReceived.containsKey(routeName) || !_manualReportReceived[routeName]!) {
      _timers[routeName]?.cancel(); // Cancel any existing timer.
      _timers[routeName] = Timer(Duration(seconds: 1), () {
        // Double-check to prevent race conditions.
        if (!_manualReportReceived.containsKey(routeName) || !_manualReportReceived[routeName]!) {
          if (!completer.isCompleted) {
            completer.complete(StrategyDecision.approximation);
          }
        }
      });
    }

    return completer.future;
  }

  bool reportManual2(String routeName) {
    var wasReportedAlready = _manualReportReceived[routeName] ?? false;
    _manualReportReceived[routeName] = true;

    // Complete the strategy decision as manual if within the timeout period.
    if (_completers[routeName]?.isCompleted == false) {
      _completers[routeName]?.complete(StrategyDecision.manual);
    }

    // Cancel the timer as it's no longer necessary.
    _timers[routeName]?.cancel();
    return wasReportedAlready;
  }

  bool reportManual(String routeName) {
    var wasReportedAlready = _manualReportReceived[routeName] ?? false;
    _manualReportReceived[routeName] = true;
    return wasReportedAlready;
  }

  void clearState(String routeName) {
    _manualReportReceived.remove(routeName);
    _timers[routeName]?.cancel();
    _timers.remove(routeName);
    _completers.remove(routeName);
  }
}

enum StrategyDecision {
  manual,
  approximation,
  undecided,
}
