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

  // TODO: remove [isReplayRecorder] parameter in the next major release, see _SentryFlutterExperimentalOptions.
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
      final srcWidth = renderObject.size.width.toInt();
      final srcHeight = renderObject.size.height.toInt();

      // In Session Replay the target size is already set and should not be changed.
      // For Screenshots, we need to calculate the target size based on the quality setting.
      config.targetHeight ??=
          config.quality.calculateHeight(srcWidth, srcHeight);
      config.targetWidth ??= config.quality.calculateWidth(srcWidth, srcHeight);

      var pixelRatio =
          config.getPixelRatio(srcWidth.toDouble(), srcHeight.toDouble());

      // First, we synchronously capture the image and enumerate widgets on the main UI loop.
      final futureImage = renderObject.toImage(pixelRatio: pixelRatio);

      final filter = _widgetFilter;
      if (filter != null) {
        filter.obscure(
          context,
          pixelRatio,
          Rect.fromLTWH(0, 0, config.targetWidth!.toDouble(),
              config.targetHeight!.toDouble()),
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
        finalImage =
            await picture.toImage(config.targetWidth!, config.targetHeight!);
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
