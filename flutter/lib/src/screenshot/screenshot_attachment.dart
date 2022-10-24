import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui show ImageByteFormat;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:sentry/sentry.dart';

import '../sentry_widget.dart';

class ScreenshotAttachment implements SentryAttachment {

  final SchedulerBinding _schedulerBinding;
  final SentryOptions _options;

  ScreenshotAttachment(this._schedulerBinding, this._options);

  @override
  String attachmentType = SentryAttachment.typeAttachmentDefault;

  @override
  String? contentType = 'image/png';

  @override
  String filename = 'screenshot.png';

  @override
  bool addToTransactions = true;

  @override
  FutureOr<Uint8List> get bytes async {
    final _completer = Completer<Uint8List?>();
    // We add an post frame callback because we aren't able to take a screenshot
    // if there's currently a draw in process.
    _schedulerBinding.addPostFrameCallback((timeStamp) async {
      final screenshot = await _createScreenshot();
      _completer.complete(screenshot);
    });
    return await _completer.future ?? Uint8List.fromList([]);
  }

  Future<Uint8List?> _createScreenshot() async {
    try {
      final renderObject = sentryWidgetGlobalKey.currentContext?.findRenderObject();

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
