import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:sentry/sentry.dart';
import '../screenshot/recorder.dart';
import '../screenshot/recorder_config.dart';
import '../screenshot/sentry_screenshot_widget.dart';
import '../sentry_flutter_options.dart';
import '../renderer/renderer.dart';
import 'package:flutter/widgets.dart' as widget;

class ScreenshotEventProcessor implements EventProcessor {
  final SentryFlutterOptions _options;

  ScreenshotEventProcessor(this._options);

  /// This is true when the SentryWidget is in the view hierarchy
  bool get _hasSentryScreenshotWidget =>
      sentryScreenshotWidgetGlobalKey.currentContext != null;

  @override
  Future<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    if (event is SentryTransaction) {
      return event;
    }

    if (event.exceptions == null &&
        event.throwable == null &&
        _hasSentryScreenshotWidget) {
      return event;
    }
    final beforeScreenshot = _options.beforeScreenshot;
    if (beforeScreenshot != null) {
      try {
        final result = beforeScreenshot(event, hint: hint);
        bool takeScreenshot;
        if (result is Future<bool>) {
          takeScreenshot = await result;
        } else {
          takeScreenshot = result;
        }
        if (!takeScreenshot) {
          return event;
        }
      } catch (exception, stackTrace) {
        _options.logger(
          SentryLevel.error,
          'The beforeScreenshot callback threw an exception',
          exception: exception,
          stackTrace: stackTrace,
        );
        if (_options.automatedTestMode) {
          rethrow;
        }
      }
    }

    final renderer = _options.rendererWrapper.getRenderer();

    if (_options.platformChecker.isWeb &&
        renderer != FlutterRenderer.canvasKit) {
      _options.logger(
        SentryLevel.debug,
        'Cannot take screenshot with ${renderer?.name} renderer.',
      );
      return event;
    }

    if (_options.attachScreenshotOnlyWhenResumed &&
        widget.WidgetsBinding.instance.lifecycleState !=
            AppLifecycleState.resumed) {
      _options.logger(SentryLevel.debug,
          'Only attaching screenshots when application state is resumed.');
      return event;
    }

    // ignore: deprecated_member_use
    var recorder = ScreenshotRecorder(
        ScreenshotRecorderConfig(quality: _options.screenshotQuality),
        _options);

    Uint8List? _screenshotData;

    await recorder.capture((Image image) async {
      _screenshotData = await _convertImageToUint8List(image);
    });

    if (_screenshotData != null) {
      hint.screenshot = SentryAttachment.fromScreenshotData(_screenshotData!);
    }

    return event;
  }

  Future<Uint8List?> _convertImageToUint8List(Image image) async {
    final byteData = await image.toByteData(format: ImageByteFormat.png);

    final bytes = byteData?.buffer.asUint8List();
    if (bytes?.isNotEmpty == true) {
      return bytes;
    } else {
      _options.logger(
          SentryLevel.debug, 'Screenshot is 0 bytes, not attaching the image.');
      return null;
    }
  }
}
