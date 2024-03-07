import 'package:flutter/cupertino.dart';
import 'time_to_initial_display_tracker.dart';

import '../frame_callback_handler.dart';

/// A widget that reports the Time To Initially Displayed (TTID) of its child widget.
///
/// This widget wraps around another widget to measure and report the time it takes
/// for the child widget to be initially displayed on the screen. This method
/// allows a more accurate measurement than what the default TTID implementation
/// provides. The TTID measurement begins when the route to the widget is pushed and ends
/// when `addPostFramecallback` is triggered.
///
/// Wrap the widget you want to measure with [SentryDisplayWidget], and ensure that you
/// have set up Sentry's routing instrumentation according to the Sentry documentation.
///
/// ```dart
/// SentryDisplayWidget(
///   child: MyWidget(),
/// )
/// ```
///
/// Make sure to configure Sentry's routing instrumentation in your app by following
/// the guidelines provided in Sentry's documentation for Flutter integrations:
/// https://docs.sentry.io/platforms/flutter/integrations/routing-instrumentation/
///
/// See also:
/// - [Sentry's documentation on Flutter integrations](https://docs.sentry.io/platforms/flutter/)
///   for more information on how to integrate Sentry into your Flutter application.
class SentryDisplayWidget extends StatefulWidget {
  final Widget child;
  final FrameCallbackHandler _frameCallbackHandler;

  SentryDisplayWidget({
    super.key,
    required this.child,
    @visibleForTesting FrameCallbackHandler? frameCallbackHandler,
  }) : _frameCallbackHandler =
            frameCallbackHandler ?? DefaultFrameCallbackHandler();

  @override
  _SentryDisplayWidgetState createState() => _SentryDisplayWidgetState();
}

class _SentryDisplayWidgetState extends State<SentryDisplayWidget> {
  @override
  void initState() {
    super.initState();
    TimeToInitialDisplayTracker().markAsManual();

    widget._frameCallbackHandler.addPostFrameCallback((_) {
      TimeToInitialDisplayTracker().completeTracking();
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
