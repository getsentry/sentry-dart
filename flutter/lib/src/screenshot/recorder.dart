import 'dart:async';
import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
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
  @protected
  final bool isReplayRecorder;

  // TODO: remove in the next major release, see recorder_test.dart.
  @visibleForTesting
  bool get hasWidgetFilter => _widgetFilter != null;

  // TODO: remove [isReplayRecorder] parameter in the next major release, see _SentryFlutterExperimentalOptions.
  ScreenshotRecorder(this.config, this.options,
      {this.isReplayRecorder = true}) {
    // see `options.experimental.privacy` docs for details
    final privacyOptions = isReplayRecorder
        ? options.experimental.privacyForReplay
        : options.experimental.privacyForScreenshots;
    final maskingConfig = privacyOptions?.buildMaskingConfig();
    if (maskingConfig != null && maskingConfig.length > 0) {
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
      config.srcWidth = renderObject.size.width.toInt();
      config.srcHeight = renderObject.size.height.toInt();
      final targetHeight =
          config.quality.calculateHeight(config.srcWidth!, config.srcHeight!);
      final targetWidth =
          config.quality.calculateWidth(config.srcWidth!, config.srcHeight!);

      final pixelRatio =
          config.getPixelRatio(targetWidth.toDouble(), targetHeight.toDouble());

      // First, we synchronously capture the image and enumerate widgets on the main UI loop.
      final futureImage = renderObject.toImage(pixelRatio: pixelRatio);

      final filter = _widgetFilter;
      if (filter != null) {
        filter.obscure(
          context,
          pixelRatio,
          Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
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
        finalImage = await picture.toImage(targetWidth, targetHeight);
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
