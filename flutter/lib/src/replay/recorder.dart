import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import 'recorder_config.dart';
import 'widget_filter.dart';
import 'scheduler.dart';

@internal
typedef ScreenshotRecorderCallback = Future<void> Function(Image);

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
          redactImages: _options.redactAllImages,
          logger: _logger);
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
      final watch = Stopwatch()..start();

      // The desired resolution (coming from the configuration) is usually
      // rounded to next multitude of 16. Therefore, we scale the image.
      final srcWidth = renderObject.size.width;
      final srcHeight = renderObject.size.height;
      final pixelRatioX = _config.width / srcWidth;
      final pixelRatioY = _config.height / srcHeight;
      final pixelRatio = min(pixelRatioY, pixelRatioX);

      // First, we synchronously capture the image and enumarete widgets on the main UI loop.
      final futureImage = renderObject.toImage(pixelRatio: pixelRatio);

      final filter = _widgetFilter;
      if (filter != null) {
        filter.setupAndClear(
          pixelRatio,
          Rect.fromLTWH(0, 0, srcWidth * pixelRatio, srcHeight * pixelRatio),
        );
        context.visitChildElements(filter.obscure);
      }

      final blockingTime = watch.elapsedMilliseconds;

      // Then we draw the image and obscure collected coordinates asynchronously.
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final image = await futureImage;
      try {
        canvas.drawImage(image, Offset.zero, Paint());
      } finally {
        image.dispose();
      }

      if (filter != null) {
        _obscureWidgets(canvas, filter.items);
      }

      final picture = recorder.endRecording();

      try {
        final finalImage = await picture.toImage(
            (srcWidth * pixelRatio).round(), (srcHeight * pixelRatio).round());
        try {
          await _callback(finalImage);
        } finally {
          finalImage.dispose();
        }
      } finally {
        picture.dispose();
      }

      _logger(
          SentryLevel.debug,
          "Replay: captured a screenshot in ${watch.elapsedMilliseconds}"
          " ms ($blockingTime ms blocking).");
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
