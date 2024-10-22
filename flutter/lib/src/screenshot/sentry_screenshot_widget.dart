import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

import 'package:flutter/widgets.dart' as widgets;

import '../../sentry_flutter.dart';
import '../sentry_flutter_options.dart';

/// Key which is used to identify the [RepaintBoundary]
@internal
final sentryScreenshotWidgetGlobalKey =
    widgets.GlobalKey(debugLabel: 'sentry_screenshot_widget');

/// You can add screenshots of [child] to crash reports by adding this widget.
/// Ideally you are adding it around your app widget like in the following
/// example.
/// ```dart
/// runApp(SentryScreenshotWidget(child: App()));
/// ```
///
/// Remarks:
/// - Depending on the place where it's used, you might have a transparent
///   background.
/// - Platform Views currently can't be captured.
/// - Works with skia renderer & canvas kit renderer if running on web. For more
///   information see https://flutter.dev/docs/development/tools/web-renderers
/// - You can only have one [SentryScreenshotWidget] widget in your widget tree at all
///   times.
class SentryScreenshotWidget extends widgets.StatefulWidget {
  final widgets.Widget child;

  const SentryScreenshotWidget({super.key, required this.child});

  @override
  _SentryScreenshotWidgetState createState() => _SentryScreenshotWidgetState();

  /// This is true when the [SentryScreenshotWidget] is in the widget tree.
  static bool get isMounted =>
      sentryScreenshotWidgetGlobalKey.currentContext != null;

  @internal
  static Future<Uint8List?> captureScreenshot(
      SentryFlutterOptions options) async {
    try {
      final renderObject =
          sentryScreenshotWidgetGlobalKey.currentContext?.findRenderObject();
      if (renderObject is RenderRepaintBoundary) {
        // ignore: deprecated_member_use
        final pixelRatio = window.devicePixelRatio;
        var imageResult = _getImage(renderObject, pixelRatio);
        Image image;
        if (imageResult is Future<Image>) {
          image = await imageResult;
        } else {
          image = imageResult;
        }
        // At the time of writing there's no other image format available which
        // Sentry understands.

        if (image.width == 0 || image.height == 0) {
          options.logger(SentryLevel.debug,
              'View\'s width and height is zeroed, not taking screenshot.');
          return null;
        }

        final targetResolution = options.screenshotQuality.targetResolution();
        if (targetResolution != null) {
          var ratioWidth = targetResolution / image.width;
          var ratioHeight = targetResolution / image.height;
          var ratio = min(ratioWidth, ratioHeight);
          if (ratio > 0.0 && ratio < 1.0) {
            imageResult = _getImage(renderObject, ratio * pixelRatio);
            if (imageResult is Future<Image>) {
              image = await imageResult;
            } else {
              image = imageResult;
            }
          }
        }
        final byteData = await image.toByteData(format: ImageByteFormat.png);

        final bytes = byteData?.buffer.asUint8List();
        if (bytes?.isNotEmpty == true) {
          return bytes;
        } else {
          options.logger(SentryLevel.debug,
              'Screenshot is 0 bytes, not attaching the image.');
          return null;
        }
      }
    } catch (exception, stackTrace) {
      options.logger(
        SentryLevel.error,
        'Taking screenshot failed.',
        exception: exception,
        stackTrace: stackTrace,
      );
      if (options.automatedTestMode) {
        rethrow;
      }
    }
    return null;
  }

  static FutureOr<Image> _getImage(
      RenderRepaintBoundary repaintBoundary, double pixelRatio) {
    // This one is a hack to use https://api.flutter.dev/flutter/rendering/RenderRepaintBoundary/toImage.html on versions older than 3.7 and https://api.flutter.dev/flutter/rendering/RenderRepaintBoundary/toImageSync.html on versions equal or newer than 3.7
    try {
      return (repaintBoundary as dynamic).toImageSync(pixelRatio: pixelRatio)
          as Image;
    } on NoSuchMethodError catch (_) {
      return repaintBoundary.toImage(pixelRatio: pixelRatio);
    }
  }
}

class _SentryScreenshotWidgetState
    extends widgets.State<SentryScreenshotWidget> {
  @override
  widgets.Widget build(widgets.BuildContext context) {
    return widgets.RepaintBoundary(
      key: sentryScreenshotWidgetGlobalKey,
      child: widget.child,
    );
  }
}
