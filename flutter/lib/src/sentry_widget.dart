import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import '../sentry_flutter.dart';

/// Key which is used to identify the [SentryWidget]
@internal
final sentryWidgetGlobalKey = GlobalKey(debugLabel: 'sentry_widget');

/// This widget serves as a wrapper to include Sentry widgets such
/// as [SentryScreenshotWidget] and [SentryUserInteractionWidget].
class SentryWidget extends StatefulWidget {
  final Widget child;
  late final Hub _hub;

  SentryWidget({
    required this.child,
    @internal Hub? hub,
  }) : super(key: sentryWidgetGlobalKey) {
    _hub = hub ?? HubAdapter();
  }

  SentryFlutterOptions? get _options =>
      // ignore: invalid_use_of_internal_member
      _hub.options is SentryFlutterOptions
          // ignore: invalid_use_of_internal_member
          ? _hub.options as SentryFlutterOptions?
          : null;

  @override
  SentryWidgetState createState() => SentryWidgetState();
}

@internal
class SentryWidgetState extends State<SentryWidget> {
  // Add a boolean to control button visibility
  bool _isScreenshotButtonVisible = false;

  // Add a method to toggle the button
  void toggleScreenshotButton(bool show) {
    setState(() {
      _isScreenshotButtonVisible = show;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget content = widget.child;
    if (widget._options?.isMultiViewApp ?? false) {
      // ignore: invalid_use_of_internal_member
      Sentry.currentHub.options.log(
        SentryLevel.debug,
        '`SentryWidget` is not available in multi-view apps.',
      );
      return content;
    } else {
      content = SentryScreenshotWidget(child: content);
      content = SentryUserInteractionWidget(child: content);
      // TODO: Move to screenshot widget...
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            Container(
              child: content,
            ),
            if (_isScreenshotButtonVisible)
              Positioned(
                right: 32,
                bottom: 32,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    SentryFlutter.hideCaptureScreenshotButton();
                    final screenshot = await SentryFlutter.captureScreenshot();

                    final currentContext =
                        widget._options?.navigatorKey?.currentContext;
                    if (currentContext != null && currentContext.mounted) {
                      SentryFlutter.showFeedbackWidget(
                        currentContext,
                        SentryFeedbackWidget.pendingAccociatedEventId,
                        screenshot: screenshot,
                      );
                    }
                  },
                  icon: Image.asset(
                    'assets/screenshotIcon.png',
                    package: 'sentry_flutter',
                    width: 22,
                    height: 22,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  label: const Text('Take Screenshot'),
                ),
              ),
          ],
        ),
      );
    }
  }
}
