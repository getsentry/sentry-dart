import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:sentry/sentry.dart';
import '../screenshot/sentry_screenshot_widget.dart';
import '../sentry_flutter_options.dart';
import 'package:flutter/rendering.dart';
import '../renderer/renderer.dart';


class ScreenshotEventProcessor implements EventProcessor {
  final SentryFlutterOptions _options;

  ScreenshotEventProcessor(this._options);

  /// This is true when the SentryWidget is in the view hierarchy
  bool get _hasSentryScreenshotWidget =>
      sentryScreenshotWidgetGlobalKey.currentContext != null;

  @override
  Future<SentryEvent?> apply(SentryEvent event, {Hint? hint}) async {
    if (event is SentryTransaction) {
      return event;
    }

    if (event.exceptions == null &&
        event.throwable == null &&
        _hasSentryScreenshotWidget) {
      return event;
    }

    final renderer = _options.rendererWrapper.getRenderer();
    if (renderer != FlutterRenderer.skia &&
        renderer != FlutterRenderer.canvasKit) {
      _options.logger(SentryLevel.debug,
          'Cannot take screenshot with ${_options.rendererWrapper.getRenderer().name} renderer.');
      return event;
    }

    if (_options.attachScreenshotWhenResumed && WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      _options.logger(SentryLevel.debug,
          'Only attaching screenshots when application state is resumed.');
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
        // ignore: deprecated_member_use
        final pixelRatio = ui.window.devicePixelRatio;
        var imageResult = _getImage(renderObject, pixelRatio);
        ui.Image image;
        if (imageResult is Future<ui.Image>) {
          image = await imageResult;
        } else {
          image = imageResult;
        }
        // At the time of writing there's no other image format available which
        // Sentry understands.

        if (image.width == 0 || image.height == 0) {
          _options.logger(SentryLevel.debug,
              'View\'s width and height is zeroed, not taking screenshot.');
          return null;
        }

        final targetResolution = _options.screenshotQuality.targetResolution();
        if (targetResolution != null) {
          var ratioWidth = targetResolution / image.width;
          var ratioHeight = targetResolution / image.height;
          var ratio = min(ratioWidth, ratioHeight);
          if (ratio > 0.0 && ratio < 1.0) {
            imageResult = _getImage(renderObject, ratio * pixelRatio);
            if (imageResult is Future<ui.Image>) {
              image = await imageResult;
            } else {
              image = imageResult;
            }
          }
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
