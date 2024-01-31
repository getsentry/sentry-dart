import 'package:flutter/cupertino.dart';
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
    // TODO: implement initState
    super.initState();
    SentryFlutter.reportInitialDisplay();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
