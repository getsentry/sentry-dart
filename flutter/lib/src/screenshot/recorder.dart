import 'dart:async';
import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../replay/scheduled_recorder_config.dart';
import 'masking_config.dart';
import 'recorder_config.dart';
import 'widget_filter.dart';

@internal
typedef ScreenshotRecorderCallback = Future<void> Function(Image);

@internal
class ScreenshotRecorder {
  @protected
  final ScreenshotRecorderConfig config;
  @protected
  final SentryFlutterOptions options;
  WidgetFilter? _widgetFilter;
  bool warningLogged = false;

  ScreenshotRecorder(this.config, this.options) {
    SentryMaskingConfig maskingConfig;
    if (config is ScheduledScreenshotRecorderConfig) {
      maskingConfig = options.experimental.replay.buildMaskingConfig();
    } else {
      maskingConfig = options.experimental.screenshot.buildMaskingConfig();
    }

    if (maskingConfig.length > 0) {
      _widgetFilter = WidgetFilter(maskingConfig, options.logger);
    }
  }

  Future<void> capture(ScreenshotRecorderCallback callback) async {
    final context = sentryScreenshotWidgetGlobalKey.currentContext;
    final renderObject = context?.findRenderObject() as RenderRepaintBoundary?;
    if (context == null || renderObject == null) {
      if (!warningLogged) {
        options.logger(
            SentryLevel.warning,
            "Replay: SentryScreenshotWidget is not attached. "
            "Skipping replay capture.");
        warningLogged = true;
      }
      return;
    }

    try {
      final watch = Stopwatch()..start();

      // On Android, the desired resolution (coming from the configuration)
      // is rounded to next multitude of 16 . Therefore, we scale the image.
      // On iOS, the screenshot resolution is not adjusted.
      final srcWidth = renderObject.size.width;
      final srcHeight = renderObject.size.height;
      final pixelRatio = config.getPixelRatio(srcWidth, srcHeight);

      // First, we synchronously capture the image and enumerate widgets on the main UI loop.
      final futureImage = renderObject.toImage(pixelRatio: pixelRatio);

      final filter = _widgetFilter;
      if (filter != null) {
        filter.obscure(
          context,
          pixelRatio,
          Rect.fromLTWH(0, 0, srcWidth * pixelRatio, srcHeight * pixelRatio),
        );
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
        Image finalImage;
        if (config is ScheduledScreenshotRecorderConfig) {
          finalImage = await picture.toImage((srcWidth * pixelRatio).round(),
              (srcHeight * pixelRatio).round());
        } else {
          final targetHeight = config.quality
              .calculateHeight(srcWidth.toInt(), srcHeight.toInt());
          final targetWidth = config.quality
              .calculateWidth(srcWidth.toInt(), srcHeight.toInt());
          finalImage = await picture.toImage(targetWidth, targetHeight);
        }
        try {
          await callback(finalImage);
        } finally {
          finalImage.dispose(); // image needs to be disposed manually
        }
      } finally {
        picture.dispose();
      }

      options.logger(
          SentryLevel.debug,
          "Replay: captured a screenshot in ${watch.elapsedMilliseconds}"
          " ms ($blockingTime ms blocking).");
    } catch (e, stackTrace) {
      options.logger(SentryLevel.error, "Replay: failed to capture screenshot.",
          exception: e, stackTrace: stackTrace);
      if (options.automatedTestMode) {
        rethrow;
      }
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
