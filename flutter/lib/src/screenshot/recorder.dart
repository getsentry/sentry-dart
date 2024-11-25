import 'dart:async';
import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' as widgets;
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
  final String _logName;
  WidgetFilter? _widgetFilter;
  bool _warningLogged = false;

  // TODO: remove in the next major release, see recorder_test.dart.
  @visibleForTesting
  bool get hasWidgetFilter => _widgetFilter != null;

  // TODO: remove [isReplayRecorder] parameter in the next major release, see _SentryFlutterExperimentalOptions.
  ScreenshotRecorder(this.config, this.options, {bool isReplayRecorder = true})
      : _logName = isReplayRecorder ? 'ReplayRecorder' : 'ScreenshotRecorder' {
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
      if (!_warningLogged) {
        options.logger(SentryLevel.warning,
            "$_logName: SentryScreenshotWidget is not attached, skipping capture.");
        _warningLogged = true;
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

      final pixelRatio = config.getPixelRatio(srcWidth, srcHeight) ??
          widgets.MediaQuery.of(context).devicePixelRatio;

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
        final finalImage = await picture.toImage(
            (srcWidth * pixelRatio).round(), (srcHeight * pixelRatio).round());
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
          "$_logName: captured a screenshot in ${watch.elapsedMilliseconds}"
          " ms ($blockingTime ms blocking).");
    } catch (e, stackTrace) {
      options.logger(
          SentryLevel.error, "$_logName: failed to capture screenshot.",
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
