import 'dart:async';
import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

import '../screenshot/sentry_screenshot_widget.dart';
import 'recorder_config.dart';
import 'recorder_widget_filter.dart';
import 'scheduler.dart';

@internal
typedef ScreenshotRecorderCallback = Future<void> Function(Image);

@internal
class ScreenshotRecorder {
  final ScreenshotRecorderConfig _config;
  final ScreenshotRecorderCallback _callback;
  late final Scheduler _scheduler;
  final Paint _widgetObscurePaint = Paint()..color = const Color(0x7f000000);

  ScreenshotRecorder(this._config, this._callback) {
    final frameDuration = Duration(milliseconds: 1000 ~/ _config.frameRate);
    _scheduler = Scheduler(frameDuration, _capture);
  }

  void start() => _scheduler.start();

  void stop() => _scheduler.stop();

  // TODO try-catch
  Future<void> _capture(Duration sinceSchedulerEpoch) async {
    final context = sentryScreenshotWidgetGlobalKey.currentContext;
    final renderObject = context?.findRenderObject();

    if (context != null && renderObject is RenderRepaintBoundary) {
      final watch = Stopwatch()..start();

      // TODO downsize right away to the desired resolution: use _config
      final width = renderObject.size.width.round();
      final height = renderObject.size.height.round();
      final pixelRatio = 1.0;

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final futureImage = renderObject.toImage(pixelRatio: pixelRatio);
      watch.printAndReset("renderObject.toImage()");

      final filter = WidgetFilter(pixelRatio);
      context.visitChildElements(filter.obscure);
      watch.printAndReset("collect widget boundaries");

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
    print("$message: $elapsedMicroseconds us");
    reset();
  }
}
