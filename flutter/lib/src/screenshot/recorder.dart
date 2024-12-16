import 'dart:async';
import 'dart:developer';
import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' as widgets;
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import 'masking_config.dart';
import 'recorder_config.dart';
import 'widget_filter.dart';

var _instanceCounter = 0;

@internal
class ScreenshotRecorder {
  @protected
  final ScreenshotRecorderConfig config;
  @protected
  final SentryFlutterOptions options;
  @protected
  late final String logName;
  bool _warningLogged = false;
  late final bool _isReplayRecorder;
  late final SentryMaskingConfig? _maskingConfig;

  // TODO: remove in the next major release, see recorder_test.dart.
  @visibleForTesting
  bool get hasWidgetFilter => _maskingConfig != null;

  ScreenshotRecorder(this.config, this.options,
      {bool isReplayRecorder = true, String? logName}) {
    _isReplayRecorder = isReplayRecorder;
    if (logName != null) {
      this.logName = logName;
    } else if (isReplayRecorder) {
      _instanceCounter++;
      this.logName = 'ReplayRecorder #$_instanceCounter';
    } else {
      this.logName = 'ScreenshotRecorder';
    }
    // see `options.experimental.privacy` docs for details
    final privacyOptions = isReplayRecorder
        ? options.experimental.privacyForReplay
        : options.experimental.privacyForScreenshots;

    final maskingConfig =
        privacyOptions?.buildMaskingConfig(_log, options.platformChecker);
    _maskingConfig = (maskingConfig?.length ?? 0) > 0 ? maskingConfig : null;
  }

  void _log(SentryLevel level, String message,
      {String? logger, Object? exception, StackTrace? stackTrace}) {
    options.logger(level, '$logName: $message',
        logger: logger, exception: exception, stackTrace: stackTrace);
  }

  void _logError(Object? e, StackTrace stackTrace) =>
      _log(SentryLevel.error, 'failed to capture screenshot.',
          exception: e, stackTrace: stackTrace);

  /// We must capture a screenshot AND execute the widget filter on the main UI
  /// loop, with no async operations in between, otherwise masks coordinates
  /// would be incorrect.
  /// To prevent accidental addition of await before that happens,
  ///
  /// THIS FUNCTION MUST NOT BE ASYNC.
  Future<R> capture<R>(Future<R> Function(Image) callback) {
    try {
      final flow = Flow.begin();
      Timeline.startSync('Sentry::captureScreenshot', flow: flow);
      final context = sentryScreenshotWidgetGlobalKey.currentContext;
      final renderObject =
          context?.findRenderObject() as RenderRepaintBoundary?;
      if (context == null || renderObject == null) {
        if (!_warningLogged) {
          _log(SentryLevel.warning,
              "SentryScreenshotWidget is not attached, skipping capture.");
          _warningLogged = true;
        }
        return Future.value(null);
      }

      final capture = _Capture<R>.create(renderObject, config, context);

      Timeline.startSync('Sentry::captureScreenshot:RenderObjectToImage',
          flow: flow);
      final futureImage = renderObject.toImage(pixelRatio: capture.pixelRatio);
      Timeline.finishSync(); // Sentry::captureScreenshot:RenderObjectToImage

      Timeline.startSync('Sentry::captureScreenshot:Masking', flow: flow);
      final obscureItems = _obscureSync(capture);
      Timeline.finishSync(); // Sentry::captureScreenshot:Masking
      Timeline.finishSync(); // Sentry::captureScreenshot

      // Then we draw the image and obscure masks later, asynchronously.
      final completer =
          capture.createTask(futureImage, callback, obscureItems, flow);
      _scheduleTask(capture.task, flow, completer);
      return completer.future;
    } catch (e, stackTrace) {
      _logError(e, stackTrace);
      if (options.automatedTestMode) {
        rethrow;
      } else {
        return Future.value(null);
      }
    }
  }

  void _scheduleTask(
      void Function() task, Flow flow, Completer<dynamic> completer) {
    late final Future<void> future;
    if (_isReplayRecorder && options.bindingUtils.instance != null) {
      future = options.bindingUtils.instance!
          .scheduleTask<void>(task, Priority.idle, flow: flow);
    } else {
      future = Future.sync(task);
    }
    future.onError((e, stackTrace) {
      _logError(e, stackTrace);
      if (e != null && options.automatedTestMode) {
        completer.completeError(e, stackTrace);
      }
    });
  }

  List<WidgetFilterItem>? _obscureSync(_Capture capture) {
    if (_maskingConfig != null) {
      final filter = WidgetFilter(_maskingConfig!, options.logger);
      final colorScheme = capture.context.findColorScheme();
      filter.obscure(
        context: capture.context,
        pixelRatio: capture.pixelRatio,
        colorScheme: colorScheme,
        bounds: capture.bounds,
      );
      return filter.items;
    }
    return null;
  }
}

class _Capture<R> {
  final widgets.BuildContext context;
  final double srcWidth;
  final double srcHeight;
  final double pixelRatio;
  late final void Function() task;

  _Capture._(
      {required this.context,
      required this.srcWidth,
      required this.srcHeight,
      required this.pixelRatio});

  factory _Capture.create(RenderRepaintBoundary renderObject,
      ScreenshotRecorderConfig config, widgets.BuildContext context) {
    // On Android, the resolution (coming from the configuration)
    // is rounded to next multitude of 16. Therefore, we scale the image.
    // On iOS, the screenshot resolution is not adjusted.
    // For screenshots, the pixel ratio is adjusted based on quality config.
    final srcWidth = renderObject.size.width;
    final srcHeight = renderObject.size.height;
    final pixelRatio = config.getPixelRatio(srcWidth, srcHeight) ??
        widgets.MediaQuery.of(context).devicePixelRatio;

    return _Capture._(
      context: context,
      srcWidth: srcWidth,
      srcHeight: srcHeight,
      pixelRatio: pixelRatio,
    );
  }

  Rect get bounds =>
      Rect.fromLTWH(0, 0, srcWidth * pixelRatio, srcHeight * pixelRatio);

  int get width => (srcWidth * pixelRatio).round();

  int get height => (srcHeight * pixelRatio).round();

  /// Creates an asynchronous task (a.k.a lambda) to
  /// - produce the image
  /// - render obscure masks
  /// - call the callback
  ///
  /// See [future] which is what gets completed with the callback result.
  Completer<R> createTask(
      Future<Image> futureImage,
      Future<R> Function(Image) callback,
      List<WidgetFilterItem>? obscureItems,
      Flow flow) {
    final completer = Completer<R>();

    task = () async {
      Timeline.startSync('Sentry::renderScreenshot', flow: flow);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final image = await futureImage;
      try {
        canvas.drawImage(image, Offset.zero, Paint());
      } finally {
        image.dispose();
      }

      if (obscureItems != null) {
        _obscureWidgets(canvas, obscureItems);
      }

      final picture = recorder.endRecording();
      Timeline.finishSync(); // Sentry::renderScreenshot

      try {
        Timeline.startSync('Sentry::screenshotToImage', flow: flow);
        final finalImage = await picture.toImage(width, height);
        Timeline.finishSync(); // Sentry::screenshotToImage
        try {
          Timeline.startSync('Sentry::screenshotCallback', flow: flow);
          completer.complete(await callback(finalImage));
          Timeline.finishSync(); // Sentry::screenshotCallback
        } finally {
          finalImage.dispose(); // image needs to be disposed-of manually
        }
      } finally {
        picture.dispose();
      }
    };
    return completer;
  }

  void _obscureWidgets(Canvas canvas, List<WidgetFilterItem> items) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var item in items) {
      paint.color = item.color;
      canvas.drawRect(item.bounds, paint);
    }
  }
}

extension on widgets.BuildContext {
  WidgetFilterColorScheme findColorScheme() {
    WidgetFilterColorScheme? result;
    visitAncestorElements((el) {
      result = getElementColorScheme(el);
      return result == null;
    });

    if (result == null) {
      int limit = 20;
      visitor(widgets.Element el) {
        // Don't take too much time trying to find the theme.
        if (limit-- < 0) {
          return;
        }

        result ??= getElementColorScheme(el);
        if (result == null) {
          el.visitChildren(visitor);
        }
      }

      visitChildElements(visitor);
    }

    assert(material.Colors.white.isOpaque);
    assert(material.Colors.black.isOpaque);
    result ??= const WidgetFilterColorScheme(
      background: material.Colors.white,
      defaultMask: material.Colors.black,
      defaultTextMask: material.Colors.black,
    );

    return result!;
  }

  WidgetFilterColorScheme? getElementColorScheme(widgets.Element el) {
    final widget = el.widget;
    if (widget is material.MaterialApp || widget is material.Scaffold) {
      final colorScheme = material.Theme.of(el).colorScheme;
      return WidgetFilterColorScheme(
        background: colorScheme.surface.asOpaque(),
        defaultMask: colorScheme.primary.asOpaque(),
        defaultTextMask: colorScheme.primary.asOpaque(),
      );
    } else if (widget is cupertino.CupertinoApp) {
      final colorScheme = cupertino.CupertinoTheme.of(el);
      final textColor = colorScheme.textTheme.textStyle.foreground?.color ??
          colorScheme.textTheme.textStyle.color ??
          colorScheme.primaryColor;
      return WidgetFilterColorScheme(
        background: colorScheme.scaffoldBackgroundColor.asOpaque(),
        defaultMask: colorScheme.primaryColor.asOpaque(),
        defaultTextMask: textColor.asOpaque(),
      );
    }
    return null;
  }
}
