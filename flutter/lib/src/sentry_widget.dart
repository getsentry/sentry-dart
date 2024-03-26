import 'package:flutter/cupertino.dart';
import 'package:meta/meta.dart';
import '../sentry_flutter.dart';

/// Key which is used to identify the [SentryWidget]
@internal
final sentryWidgetGlobalKey = GlobalKey(debugLabel: 'sentry_widget');

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
    return Container(
      key: sentryWidgetGlobalKey,
      child: content,
    );
  }
}
