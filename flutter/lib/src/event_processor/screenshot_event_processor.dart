import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:meta/meta.dart';
import '../../sentry_flutter.dart';
import '../renderer/renderer.dart';
import '../screenshot/recorder.dart';
import '../screenshot/recorder_config.dart';
import 'package:flutter/widgets.dart' as widget;

import '../utils/debouncer.dart';

class ScreenshotEventProcessor implements EventProcessor {
  final SentryFlutterOptions _options;

  late final ScreenshotRecorder _recorder;
  late final Debouncer _debouncer;

  ScreenshotEventProcessor(this._options) {
    final targetResolution = _options.screenshotQuality.targetResolution();
    _recorder = ScreenshotRecorder(
      ScreenshotRecorderConfig(
        width: targetResolution,
        height: targetResolution,
      ),
      _options,
    );
    _debouncer = Debouncer(
      // ignore: invalid_use_of_internal_member
      _options.clock,
      waitTime: Duration(milliseconds: 2000),
    );
  }

  @override
  Future<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    if (event is SentryTransaction) {
      return event;
    }

    if (event.exceptions == null &&
        event.throwable == null &&
        SentryScreenshotWidget.isMounted) {
      return event;
    }

    if (event.type == 'feedback') {
      return event; // No need to attach screenshot of feedback form.
    }

    // skip capturing in case of debouncing (=too many frequent capture requests)
    // the BeforeCaptureCallback may overrule the debouncing decision
    final shouldDebounce = _debouncer.shouldDebounce();

    // ignore: deprecated_member_use_from_same_package
    final beforeScreenshot = _options.beforeScreenshot;
    final beforeCapture = _options.beforeCaptureScreenshot;

    try {
      FutureOr<bool>? result;

      if (beforeCapture != null) {
        result = beforeCapture(event, hint, shouldDebounce);
      } else if (beforeScreenshot != null) {
        result = beforeScreenshot(event, hint: hint);
      }

      bool takeScreenshot = true;

      if (result != null) {
        if (result is Future<bool>) {
          takeScreenshot = await result;
        } else {
          takeScreenshot = result;
        }
      } else if (shouldDebounce) {
        _options.logger(
          SentryLevel.debug,
          'Skipping screenshot capture due to debouncing (too many captures within ${_debouncer.waitTime}ms)',
        );
        takeScreenshot = false;
      }

      if (!takeScreenshot) {
        return event;
      }
    } catch (exception, stackTrace) {
      _options.logger(
        SentryLevel.error,
        'The beforeCaptureScreenshot/beforeScreenshot callback threw an exception',
        exception: exception,
        stackTrace: stackTrace,
      );
      if (_options.automatedTestMode) {
        rethrow;
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

    final screenshotData = await createScreenshot();
    if (screenshotData != null) {
      hint.screenshot = SentryAttachment.fromScreenshotData(screenshotData);
    }

    return event;
  }

  @internal
  Future<Uint8List?> createScreenshot() =>
      _recorder.capture(_convertImageToUint8List);

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
