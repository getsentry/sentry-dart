import 'dart:async';
import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import 'recorder_config.dart';
import 'recorder_widget_filter.dart';
import 'scheduler.dart';

@internal
typedef ScreenshotRecorderCallback = Future<void> Function(Image);

@internal
class ScreenshotRecorder {
  final ScreenshotRecorderConfig _config;
  final ScreenshotRecorderCallback _callback;
  final SentryLogger _logger;
  late final Scheduler _scheduler;
  final Paint _widgetObscurePaint = Paint()
    ..color = Color.fromARGB(255, 0, 0, 0);
  bool warningLogged = false;

  ScreenshotRecorder(this._config, this._callback, this._logger) {
    final frameDuration = Duration(milliseconds: 1000 ~/ _config.frameRate);
    _scheduler = Scheduler(frameDuration, _capture);
  }

  void start() {
    _logger(SentryLevel.debug, "Replay: starting replay capture.");
    _scheduler.start();
  }

  void stop() {
    _scheduler.stop();
    _logger(SentryLevel.debug, "Replay: replay capture stopped.");
  }

  // TODO try-catch
  Future<void> _capture(Duration sinceSchedulerEpoch) async {
    final context = sentryScreenshotWidgetGlobalKey.currentContext;
    final renderObject = context?.findRenderObject() as RenderRepaintBoundary?;

    if (context == null || renderObject == null) {
      if (!warningLogged) {
        _logger(
            SentryLevel.warning,
            "Replay: SentryScreenshotWidget is not attached. "
            "Skipping replay capture.");
        warningLogged = true;
      }
      return;
    }

    try {
      // TODO remove these
      final watch = Stopwatch()..start();
      final watch2 = Stopwatch()..start();

      final width = renderObject.size.width.round();
      final height = renderObject.size.height.round();
      final pixelRatio = 1.0;

      // Note: we capture the image first and visit children synchronously on the main UI loop.
      final futureImage = renderObject.toImage(pixelRatio: pixelRatio);
      watch.printAndReset("renderObject.toImage($pixelRatio)");

      final filter = WidgetFilter(pixelRatio);
      context.visitChildElements(filter.obscure);
      watch.printAndReset("collect widget boundaries");

      // Then we draw the image and obscure collected coordinates asynchronously.
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final image = await futureImage;
      watch.printAndReset("await image");
      try {
        canvas.drawImage(image, Offset.zero, Paint());
        watch.printAndReset("drawImage()");
      } finally {
        image.dispose();
      }

      _obscureWidgets(canvas, filter.bounds);
      watch.printAndReset("obscureWidgets()");

      final picture = recorder.endRecording();
      watch.printAndReset("endRecording()");

      try {
        final finalImage = await picture.toImage(width, height);
        watch.printAndReset("picture.toImage()");
        try {
          await _callback(finalImage);
          watch.printAndReset("callback()");
        } finally {
          finalImage.dispose();
        }
      } finally {
        picture.dispose();
      }

      _logger(SentryLevel.debug,
          "Replay: captured a screenshot in ${watch2.elapsedMilliseconds} ms.");
      watch2.printAndReset("complete capture");
    } catch (e, stackTrace) {
      _logger(SentryLevel.error, "Replay: failed to capture screenshot.",
          exception: e, stackTrace: stackTrace);
    }
  }

  void _obscureWidgets(Canvas canvas, List<Rect> widgetBounds) {
    for (var bounds in widgetBounds) {
      canvas.drawRect(bounds, _widgetObscurePaint);
    }
  }
}

extension _WatchPrinter on Stopwatch {
  void printAndReset(String message) {
    print(
        "RECORDER | $message: ${(elapsedMicroseconds / 1000).toStringAsFixed(3)} ms");
    reset();
  }
}
