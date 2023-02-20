import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui show ImageByteFormat, Image;

import 'package:sentry/sentry.dart';
import '../screenshot/sentry_screenshot_widget.dart';
import '../sentry_flutter_options.dart';
import 'package:flutter/rendering.dart';
import '../renderer/renderer.dart';

class ScreenshotEventProcessor extends EventProcessor {
  final SentryFlutterOptions _options;

  ScreenshotEventProcessor(this._options);

  /// This is true when the SentryWidget is in the view hierarchy
  bool get _hasSentryScreenshotWidget =>
      sentryScreenshotWidgetGlobalKey.currentContext != null;

  @override
  FutureOr<SentryEvent?> apply(SentryEvent event, {hint}) async {
    if (event.exceptions == null &&
        event.throwable == null &&
        _hasSentryScreenshotWidget) {
      return event;
    }

    final renderer = _options.rendererWrapper.getRenderer();
    if (renderer != FlutterRenderer.skia &&
        renderer != FlutterRenderer.canvasKit) {
      _options.logger(SentryLevel.debug,
          'Cannot take screenshot with ${_options.rendererWrapper.getRendererAsString()} renderer.');
      return event;
    }

    final bytes = await _createScreenshot();
    if (bytes != null) {
      hint?.screenshot = SentryAttachment.fromScreenshotData(bytes);
    }
    return event;
  }

  Future<Uint8List?> _createScreenshot() async {
    try {
      final renderObject =
          sentryScreenshotWidgetGlobalKey.currentContext?.findRenderObject();

      if (renderObject is RenderRepaintBoundary) {
        final result = _getImage(renderObject, 1);
        ui.Image image;
        if (result is Future) {
          image = await result;
        } else {
          image = result;
        }
        // At the time of writing there's no other image format available which
        // Sentry understands.

        if (image.width == 0 || image.height == 0) {
          _options.logger(SentryLevel.debug,
              'View\'s width and height is zeroed, not taking screenshot.');
          return null;
        }

        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final bytes = byteData?.buffer.asUint8List();
        if (bytes?.isNotEmpty == true) {
          return bytes;
        } else {
          _options.logger(SentryLevel.debug,
              'Screenshot is 0 bytes, not attaching the image.');
          return null;
        }
      }
    } catch (exception, stackTrace) {
      _options.logger(
        SentryLevel.error,
        'Taking screenshot failed.',
        exception: exception,
        stackTrace: stackTrace,
      );
    }
    return null;
  }

  FutureOr<ui.Image> _getImage(
      RenderRepaintBoundary repaintBoundary, double pixelRatio) {
    // This one is a hack to use https://api.flutter.dev/flutter/rendering/RenderRepaintBoundary/toImage.html on versions older than 3.7 and https://api.flutter.dev/flutter/rendering/RenderRepaintBoundary/toImageSync.html on versions equal or newer than 3.7
    try {
      return (repaintBoundary as dynamic).toImageSync(pixelRatio: pixelRatio)
          as ui.Image;
    } on NoSuchMethodError catch (_) {
      return repaintBoundary.toImage(pixelRatio: pixelRatio);
    }
  }
}
