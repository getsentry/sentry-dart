import 'package:flutter/cupertino.dart';

import '../../sentry_flutter.dart';

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