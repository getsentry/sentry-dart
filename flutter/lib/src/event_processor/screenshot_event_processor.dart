import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:sentry/sentry.dart';
import '../screenshot/sentry_screenshot_widget.dart';
import '../sentry_flutter_options.dart';
import 'package:flutter/rendering.dart';
import '../renderer/renderer.dart';
import 'package:flutter/widgets.dart' as widget;

class ScreenshotEventProcessor implements EventProcessor {
  final SentryFlutterOptions _options;

  ScreenshotEventProcessor(this._options);

  /// This is true when the SentryWidget is in the view hierarchy
  bool get _hasSentryScreenshotWidget =>
      sentryScreenshotWidgetGlobalKey.currentContext != null;

  @override
  Future<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    if (event is SentryTransaction) {
      return event;
    }

    if (event.exceptions == null &&
        event.throwable == null &&
        _hasSentryScreenshotWidget) {
      return event;
    }
    final beforeScreenshot = _options.beforeScreenshot;
    if (beforeScreenshot != null) {
      try {
        final result = beforeScreenshot(event, hint: hint);
        bool takeScreenshot;
        if (result is Future<bool>) {
          takeScreenshot = await result;
        } else {
          takeScreenshot = result;
        }
        if (!takeScreenshot) {
          return event;
        }
      } catch (exception, stackTrace) {
        _options.logger(
          SentryLevel.error,
          'The beforeScreenshot callback threw an exception',
          exception: exception,
          stackTrace: stackTrace,
        );
        // ignore: invalid_use_of_internal_member
        if (_options.automatedTestMode) {
          rethrow;
        }
      }
    }

    final renderer = _options.rendererWrapper.getRenderer();

    if (_options.platformChecker.isWeb &&
        renderer != FlutterRenderer.canvasKit) {
      _options.logger(
        SentryLevel.debug,
        'Cannot take screenshot with ${renderer?.name} renderer.',
      );
      return event;
    }

    if (_options.attachScreenshotOnlyWhenResumed &&
        widget.WidgetsBinding.instance.lifecycleState !=
            AppLifecycleState.resumed) {
      _options.logger(SentryLevel.debug,
          'Only attaching screenshots when application state is resumed.');
      return event;
    }

    final bytes = await _createScreenshot();
    if (bytes != null) {
      hint.screenshot = SentryAttachment.fromScreenshotData(bytes);
    }
    return event;
  }

  Future<Uint8List?> _createScreenshot() async {
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

  FutureOr<Image> _getImage(
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
