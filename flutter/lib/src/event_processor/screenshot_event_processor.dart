import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:sentry/sentry.dart';
import '../replay/recorder.dart';
import '../replay/recorder_config.dart';
import '../screenshot/sentry_screenshot_widget.dart';
import '../sentry_flutter_options.dart';
import '../renderer/renderer.dart';
import 'package:flutter/widgets.dart' as widget;

class ScreenshotEventProcessor implements EventProcessor {
  final SentryFlutterOptions _options;
  late ScreenshotRecorder _screenshotRecorder;

  ScreenshotEventProcessor(this._options) {
    _screenshotRecorder =
        ScreenshotRecorder(ScreenshotRecorderConfig(), _options);
  }

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
        // ignore: invalid_use_of_internal_member
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

    final bytes = await _createScreenshot();
    if (bytes != null) {
      hint.screenshot = SentryAttachment.fromScreenshotData(bytes);
    }
    return event;
  }

  Future<Uint8List?> _createScreenshot() async {
    Completer<Uint8List?> completer = Completer<Uint8List?>();

    await _screenshotRecorder.capture((Image image) async {
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();

      if (bytes?.isNotEmpty == true) {
        completer.complete(bytes);
      } else {
        _options.logger(SentryLevel.debug,
            'Screenshot is 0 bytes, not attaching the image.');
        completer.complete(null);
      }
    });

    final screenshotTimeout = Duration(seconds: 2);
    return completer.future.timeout(
      screenshotTimeout,
      onTimeout: () {
        _options.logger(
          SentryLevel.warning,
          'Screenshot took more than $screenshotTimeout seconds to capture.',
        );
        return null;
      },
    );
  }
}
