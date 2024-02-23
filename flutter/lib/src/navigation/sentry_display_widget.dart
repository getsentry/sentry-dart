import 'package:flutter/cupertino.dart';
import 'time_to_initial_display_tracker.dart';

import '../frame_callback_handler.dart';

class SentryDisplayWidget extends StatefulWidget {
  final Widget child;
  final FrameCallbackHandler _frameCallbackHandler;

  SentryDisplayWidget({
    super.key,
    required this.child,
    FrameCallbackHandler? frameCallbackHandler,
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
