import 'dart:async';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import '../../sentry_flutter.dart';
import '../screenshot/recorder.dart';
import '../screenshot/recorder_config.dart';

import '../screenshot/screenshot_support.dart';
import '../utils/debouncer.dart';

class ScreenshotEventProcessor implements EventProcessor {
  final SentryFlutterOptions _options;

  late final ScreenshotRecorder _recorder;
  late final Debouncer _debouncer;

  ScreenshotEventProcessor(this._options) {
    final targetResolution = _options.screenshotQuality.targetResolution();
    _recorder = ScreenshotRecorder(_options,
        config: ScreenshotRecorderConfig(
          width: targetResolution,
          height: targetResolution,
        ));
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

    final renderer = _options.rendererWrapper.renderer;
    if (!_options.isScreenshotSupported) {
      _options.log(
        SentryLevel.debug,
        'Screenshot: not supported in this environment with renderer $renderer',
      );
      return event;
    }

    // skip capturing in case of debouncing (=too many frequent capture requests)
    // the BeforeCaptureCallback may overrule the debouncing decision
    final shouldDebounce = _debouncer.shouldDebounce();
    final beforeCaptureScreenshot = _options.beforeCaptureScreenshot;

    try {
      FutureOr<bool>? result;

      if (beforeCaptureScreenshot != null) {
        result = beforeCaptureScreenshot(event, hint, shouldDebounce);
      }

      bool takeScreenshot = true;

      if (result != null) {
        if (result is Future<bool>) {
          takeScreenshot = await result;
        } else {
          takeScreenshot = result;
        }
      } else if (shouldDebounce) {
        _options.log(
          SentryLevel.debug,
          'Screenshot: skipping capture due to debouncing (too many captures within ${_debouncer.waitTime.inMilliseconds}ms)',
        );
        takeScreenshot = false;
      }

      if (!takeScreenshot) {
        return event;
      }
    } catch (exception, stackTrace) {
      _options.log(
        SentryLevel.error,
        'Screenshot: the beforeCaptureScreenshot/beforeScreenshot callback threw an exception',
        exception: exception,
        stackTrace: stackTrace,
      );
      if (_options.automatedTestMode) {
        rethrow;
      }
    }

    final screenshotData = await createScreenshot();
    if (screenshotData != null) {
      hint.screenshot = SentryAttachment.fromScreenshotData(screenshotData);
    }

    return event;
  }

  @internal
  Future<Uint8List?> createScreenshot() => _recorder.capture(
      (screenshot) => screenshot.pngData.then((v) => v.buffer.asUint8List()));
}
