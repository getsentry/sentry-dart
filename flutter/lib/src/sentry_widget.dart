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
