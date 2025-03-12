import 'dart:async';
import 'dart:developer';
import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' as widgets;
import 'package:flutter/material.dart' as material;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import 'masking_config.dart';
import 'recorder_config.dart';
import 'screenshot.dart';
import 'widget_filter.dart';

@internal
class ScreenshotRecorder {
  @protected
  final ScreenshotRecorderConfig config;

  @protected
  final SentryFlutterOptions options;

  final String logName;
  bool _warningLogged = false;
  late final SentryMaskingConfig? _maskingConfig;

  ScreenshotRecorder(
    this.config,
    this.options, {
    SentryPrivacyOptions? privacyOptions,
    this.logName = 'ScreenshotRecorder',
  }) {
    privacyOptions ??= options.privacy;

    final maskingConfig =
        privacyOptions.buildMaskingConfig(_log, options.runtimeChecker);
    _maskingConfig = maskingConfig.length > 0 ? maskingConfig : null;
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
  Future<R> capture<R>(Future<R> Function(Screenshot) callback, [Flow? flow]) {
    try {
      flow ??= Flow.begin();
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

      // Then we draw the image and obscure masks later, asynchronously.
      final task =
          capture.createTask(futureImage, callback, obscureItems, flow);
      executeTask(task, flow).onError((e, stackTrace) {
        _logError(e, stackTrace);
        if (e != null && options.automatedTestMode) {
          capture._completer.completeError(e, stackTrace);
        } else {
          capture._completer.complete(null);
        }
      });
      Timeline.finishSync(); // Sentry::captureScreenshot
      return capture.future;
    } catch (e, stackTrace) {
      _logError(e, stackTrace);
      if (options.automatedTestMode) {
        rethrow;
      } else {
        return Future.value(null);
      }
    }
  }

  @protected
  Future<void> executeTask(Future<void> Function() task, Flow flow) {
    // Future.sync() starts executing the function synchronously, until the
    // first await, i.e. it's the same as if the code was executed directly.
    return Future.sync(task);
  }

  List<WidgetFilterItem>? _obscureSync(_Capture<dynamic> capture) {
    if (_maskingConfig != null) {
      final filter = WidgetFilter(_maskingConfig, options.logger);
      final colorScheme = capture.context.findColorScheme();
      filter.obscure(
        root: capture.root,
        context: capture.context,
        colorScheme: colorScheme,
      );
      return filter.items;
    }
    return null;
  }
}

class _Capture<R> {
  final RenderRepaintBoundary root;
  final widgets.BuildContext context;
  final double srcWidth;
  final double srcHeight;
  final double pixelRatio;
  final _completer = Completer<R>();

  _Capture._(
      {required this.root,
      required this.context,
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
      root: renderObject,
      context: context,
      srcWidth: srcWidth,
      srcHeight: srcHeight,
      pixelRatio: pixelRatio,
    );
  }

  int get width => (srcWidth * pixelRatio).round();

  int get height => (srcHeight * pixelRatio).round();

  Future<R> get future => _completer.future;

  /// Creates an asynchronous task (a.k.a lambda) to:
  /// - produce the image
  /// - render obscure masks
  /// - call the callback
  ///
  /// See [task] which is what gets completed with the callback result.
  Future<void> Function() createTask(
    Future<Image> futureImage,
    Future<R> Function(Screenshot) callback,
    List<WidgetFilterItem>? obscureItems,
    Flow flow,
  ) {
    final timestamp = DateTime.now();
    return () async {
      Timeline.startSync('Sentry::renderScreenshot', flow: flow);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final image = await futureImage;

      // Note: there's a weird bug when we write image to canvas directly.
      // If the UI is updating quickly in some apps, the image could get
      // out-of-sync with the UI and/or it can get completely mangled.
      // This can be reproduced, for example, by switching between Spotube's
      // Search vs Library (2nd and 3rd bottom bar buttons).
      // Weirdly, dumping the image data seems to prevent this issue...
      {
        // we do so in a block so it can be GC'ed early.
        final _ = await image.toByteData();
      }

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

      late Image finalImage;
      try {
        Timeline.startSync('Sentry::screenshotToImage', flow: flow);
        finalImage = await picture.toImage(width, height);
        Timeline.finishSync(); // Sentry::screenshotToImage
      } finally {
        picture.dispose();
      }

      final screenshot = Screenshot(finalImage, timestamp, flow);
      try {
        Timeline.startSync('Sentry::screenshotCallback', flow: flow);
        _completer.complete(await callback(screenshot));
        Timeline.finishSync(); // Sentry::screenshotCallback
      } finally {
        screenshot.dispose();
      }
    };
  }

  void _obscureWidgets(Canvas canvas, List<WidgetFilterItem> items) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var item in items) {
      paint.color = item.color;
      final source = item.bounds;
      final scaled = Rect.fromLTRB(
          source.left * pixelRatio,
          source.top * pixelRatio,
          source.right * pixelRatio,
          source.bottom * pixelRatio);
      canvas.drawRect(scaled, paint);
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
