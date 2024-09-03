import 'package:flutter/cupertino.dart';
import 'package:meta/meta.dart';
import '../sentry_flutter.dart';

/// This widget serves as a wrapper to include Sentry widgets such
/// as [SentryScreenshotWidget] and [SentryUserInteractionWidget].
class SentryWidget extends StatefulWidget {
  final Widget child;
  final GlobalKey<State<StatefulWidget>> sentryWidgetGlobalKey;
  final GlobalKey<State<StatefulWidget>> sentryScreenshotWidgetGlobalKey;

  const SentryWidget({
    super.key,
    required this.child,
    required this.sentryWidgetGlobalKey,
    required this.sentryScreenshotWidgetGlobalKey,
  });

  @override
  _SentryWidgetState createState() => _SentryWidgetState();
}

class _SentryWidgetState extends State<SentryWidget> {
  @override
  Widget build(BuildContext context) {
    Widget content = widget.child;
    content = SentryScreenshotWidget(
      sentryScreenshotWidgetGlobalKey: widget.sentryScreenshotWidgetGlobalKey,
      child: content,
    );
    content = SentryUserInteractionWidget(child: content);
    return Container(
      key: widget.sentryWidgetGlobalKey,
      child: content,
    );
  }
}
