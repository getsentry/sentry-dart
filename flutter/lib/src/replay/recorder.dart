import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import 'recorder_config.dart';
import 'recorder_widget_filter.dart';
import 'scheduler.dart';

@internal
typedef ScreenshotRecorderCallback = Future<void> Function(Image);

// TODO evaluate [notifications](https://api.flutter.dev/flutter/widgets/Notification-class.html)
// to only collect screenshots when there are changes.
// We probably can't use build() because inner repaintboundaries won't propagate up?
@internal
class ScreenshotRecorder {
  final ScreenshotRecorderConfig _config;
  final ScreenshotRecorderCallback _callback;
  final SentryLogger _logger;
  final SentryReplayOptions _options;
  WidgetFilter? _widgetFilter;
  late final Scheduler _scheduler;
  bool warningLogged = false;

  ScreenshotRecorder(
      this._config, this._callback, this._logger, this._options) {
    final frameDuration = Duration(milliseconds: 1000 ~/ _config.frameRate);
    _scheduler = Scheduler(frameDuration, _capture);
    if (_options.redactAllText || _options.redactAllImages) {
      _widgetFilter = WidgetFilter(
          redactText: _options.redactAllText,
          redactImages: _options.redactAllImages);
    }
  }

  void start() {
    _logger(SentryLevel.debug, "Replay: starting replay capture.");
    _scheduler.start();
  }

  void stop() {
    _scheduler.stop();
    _logger(SentryLevel.debug, "Replay: replay capture stopped.");
  }

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

      // The desired resolution (coming from the configuration) is usually
      // rounded to next multitude of 16. Therefore, we scale the image.
      final srcWidth = renderObject.size.width;
      final srcHeight = renderObject.size.height;
      final pixelRatioX = _config.width / srcWidth;
      final pixelRatioY = _config.height / srcHeight;
      final pixelRatio = min(pixelRatioY, pixelRatioX);

      // First, we synchronously capture the image and enumarete widgets on the main UI loop.
      final futureImage = renderObject.toImage(pixelRatio: pixelRatio);
      watch.printAndReset("renderObject.toImage($pixelRatio)");

      final filter = _widgetFilter;
      if (filter != null) {
        filter.setupAndClear(
          pixelRatio,
          Rect.fromLTWH(0, 0, srcWidth * pixelRatio, srcHeight * pixelRatio),
        );
        context.visitChildElements(filter.obscure);
        watch.printAndReset("collect widget boundaries");
      }

      final blockingTime = watch2.elapsedMilliseconds;

      // Then we draw the image and obscure collected coordinates asynchronously.
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final image = await futureImage;
      watch.printAndReset("await image (${image.width}x${image.height})");
      try {
        canvas.drawImage(image, Offset.zero, Paint());
        watch.printAndReset("drawImage()");
      } finally {
        image.dispose();
      }

      if (filter != null) {
        _obscureWidgets(canvas, filter.items);
        watch.printAndReset("obscureWidgets(${filter.items.length} items)");
      }

      final picture = recorder.endRecording();
      watch.printAndReset("endRecording()");

      try {
        final finalImage = await picture.toImage(
            (srcWidth * pixelRatio).round(), (srcHeight * pixelRatio).round());
        watch.printAndReset(
            "picture.toImage(${finalImage.width}x${finalImage.height})");
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
          "Replay: captured a screenshot in ${watch2.elapsedMilliseconds} ms ($blockingTime ms blocking).");
      watch2.printAndReset("complete capture");
    } catch (e, stackTrace) {
      _logger(SentryLevel.error, "Replay: failed to capture screenshot.",
          exception: e, stackTrace: stackTrace);
    }
  }

  void _obscureWidgets(Canvas canvas, List<WidgetFilterItem> items) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var item in items) {
      paint.color = item.color;
      canvas.drawRect(item.bounds, paint);
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
