import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:sentry/sentry.dart';

/// Key which is used to identify the [RepaintBoundary] which gets captured
final _gloablKey = GlobalKey(debugLabel: 'sentry_screenshot');

/// You can add screenshots of [child] to crash reports by adding this widget.
/// Ideally you are adding it around your app widget like in the following
/// example.
/// ```dart
/// runApp(SentryScreenshot(child: App()));
/// ```
///
/// Remarks:
/// - Depending on the place where it's used, you might have a transparent
///   background.
/// - Platform Views currently can't be captured.
/// - It only works on Flutters Canvas Kit Web renderer. For more information
///   see https://flutter.dev/docs/development/tools/web-renderers
/// - You can only have one [SentryScreenshot] widget in your widget tree at all
///   times.
class SentryScreenshot extends StatefulWidget {
  const SentryScreenshot({Key? key, required this.child, this.hub})
      : super(key: key);

  final Widget child;
  final Hub? hub;

  @override
  _SentryScreenshotState createState() => _SentryScreenshotState();
}

class _SentryScreenshotState extends State<SentryScreenshot> {
  Hub get hub => widget.hub ?? HubAdapter();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _gloablKey,
      child: widget.child,
    );
  }

  @override
  void initState() {
    super.initState();
    hub.configureScope((scope) {
      scope.addAttachment(ScreenshotAttachment());
    });
  }

  @override
  void dispose() {
    hub.configureScope((scope) {
      // The following doesn't work
      // scope.attachements.remove(ScreenshotAttachment());
    });
    super.dispose();
  }
}

class ScreenshotAttachment implements SentryAttachment {
  ScreenshotAttachment();

  @override
  String attachmentType = SentryAttachment.typeAttachmentDefault;

  @override
  String? contentType = 'image/png';

  @override
  String filename = 'screenshot.png';

  @override
  FutureOr<Uint8List> get bytes async {
    //return await createScreenshot() ?? Uint8List.fromList([]);
    final instance = SchedulerBinding.instance;
    if (instance == null) {
      return Uint8List.fromList([]);
    }

    final _completer = Completer<Uint8List?>();
    // We add an post frame callback because we aren't able to take a screenshot
    // if there's currently a draw in process.
    instance.addPostFrameCallback((timeStamp) async {
      final image = await createScreenshot();
      _completer.complete(image);
    });
    return await _completer.future ?? Uint8List.fromList([]);
  }

  @visibleForTesting
  Future<Uint8List?> createScreenshot() async {
    try {
      final renderObject = _gloablKey.currentContext?.findRenderObject();

      if (renderObject is RenderRepaintBoundary) {
        final image = await renderObject.toImage(pixelRatio: 1);
        // At the time of writing there's no other image format available which
        // Sentry understands.
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        return bytes?.buffer.asUint8List();
      }
    } catch (_) {}
    return null;
  }
}
