import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
      SentryFlutter.reportInitialDisplay(context);
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

  void startTimeout(String routeName, Function onTimeout) {
    _timers[routeName]?.cancel(); // Cancel any existing timer
    _timers[routeName] = Timer(Duration(seconds: 2), () {
      // Don't send if we already received a manual report or if we're on the root route e.g App start.
      if (!(_manualReportReceived[routeName] ?? false)) {
        onTimeout();
      }
    });
  }

  bool reportManual(String routeName) {
    var wasReportedAlready = _manualReportReceived[routeName] ?? false;
    _manualReportReceived[routeName] = true;
    _timers[routeName]?.cancel();
    return wasReportedAlready;
  }

  void clearState(String routeName) {
    _manualReportReceived.remove(routeName);
    _timers[routeName]?.cancel();
    _timers.remove(routeName);
  }
}
