import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui show ImageByteFormat;

import 'package:flutter/rendering.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/sentry_private.dart';
import '../integrations/native_app_start_integration.dart';
import '../renderer/renderer.dart';
import '../sentry_flutter_options.dart';
import 'sentry_screenshot_widget.dart';

// ignore: invalid_use_of_internal_member
class ScreenshotAttachmentProcessor implements SentryClientAttachmentProcessor {
  final SchedulerBindingProvider _schedulerBindingProvider;
  final SentryFlutterOptions _options;

  ScreenshotAttachmentProcessor(this._schedulerBindingProvider, this._options);

  /// This is true when the SentryWidget is in the view hierarchy
  bool get _attachScreenshot =>
      sentryScreenshotWidgetGlobalKey.currentContext != null;

  @override
  Future<List<SentryAttachment>> processAttachments(
      List<SentryAttachment> attachments, SentryEvent event) async {
    if (event.exceptions == null &&
        event.throwable == null &&
        _attachScreenshot) {
      return attachments;
    }
    final renderer = _options.rendererWrapper.getRenderer();
    if (renderer != FlutterRenderer.skia &&
        renderer != FlutterRenderer.canvasKit) {
      return attachments;
    }

    final schedulerBinding = _schedulerBindingProvider();
    if (schedulerBinding != null) {
      final completer = Completer<Uint8List?>();

      schedulerBinding.addPostFrameCallback((timeStamp) async {
        final screenshot = await _createScreenshot();
        completer.complete(screenshot);
      });
      final bytes = await completer.future;
      if (bytes == null) {
        return attachments;
      }
      return attachments + [SentryAttachment.fromScreenshotData(bytes)];
    } else {
      return attachments;
    }
  }

  Future<Uint8List?> _createScreenshot() async {
    try {
      final renderObject =
          sentryScreenshotWidgetGlobalKey.currentContext?.findRenderObject();

      if (renderObject is RenderRepaintBoundary) {
        final image = await renderObject.toImage(pixelRatio: 1);
        // At the time of writing there's no other image format available which
        // Sentry understands.

        if (image.width == 0 || image.height == 0) {
          _options.logger(SentryLevel.debug,
              'View\'s width and height is zeroed, not taking screenshot.');
          return null;
        }

        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final bytes = byteData?.buffer.asUint8List() ?? Uint8List(0);
        if (bytes.isNotEmpty) {
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
}
