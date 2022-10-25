import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui show ImageByteFormat;

import 'package:flutter/rendering.dart';
import 'package:sentry/sentry.dart';
import '../integrations/native_app_start_integration.dart';
import '../sentry_widget.dart';

class ScreenshotAttachmentProcessor implements SentryClientAttachmentProcessor {
  final SchedulerBindingProvider _schedulerBindingProvider;
  final SentryOptions _options;

  ScreenshotAttachmentProcessor(this._schedulerBindingProvider, this._options);

  /// This is true when the SentryWidget is in the view hierarchy
  bool get _attachScreenshot => sentryWidgetGlobalKey.currentContext != null;

  @override
  Future<List<SentryAttachment>> processAttachments(
      List<SentryAttachment> attachments, SentryEvent event) async {
    if (event.exceptions == null &&
        event.throwable == null &&
        _attachScreenshot) {
      return attachments;
    }
    final schedulerBinding = _schedulerBindingProvider();
    if (schedulerBinding != null) {
      final completer = Completer<Uint8List?>();
      schedulerBinding.addPostFrameCallback((timeStamp) async {
        final screenshot = await _createScreenshot();
        completer.complete(screenshot);
      });
      final bytes = await completer.future ?? Uint8List.fromList([]);
      final screenshotAttachment = SentryAttachment.fromScreenshotData(bytes);

      final attachments = <SentryAttachment>[];
      attachments.addAll(attachments);
      attachments.add(screenshotAttachment);
      return attachments;
    } else {
      return attachments;
    }
  }

  Future<Uint8List?> _createScreenshot() async {
    try {
      final renderObject =
          sentryWidgetGlobalKey.currentContext?.findRenderObject();

      if (renderObject is RenderRepaintBoundary) {
        final image = await renderObject.toImage(pixelRatio: 1);
        // At the time of writing there's no other image format available which
        // Sentry understands.
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        return bytes?.buffer.asUint8List();
      }
    } catch (exception, stackTrace) {
      _options.logger(
        SentryLevel.error,
        'Could not create screenshot.',
        exception: exception,
        stackTrace: stackTrace,
      );
    }
    return null;
  }
}
