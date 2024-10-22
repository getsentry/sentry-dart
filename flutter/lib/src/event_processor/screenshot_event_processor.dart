import 'dart:async';
import 'dart:ui';

import 'package:sentry/sentry.dart';
import '../screenshot/sentry_screenshot_widget.dart';
import '../sentry_flutter_options.dart';
import '../renderer/renderer.dart';
import 'package:flutter/widgets.dart' as widget;

class ScreenshotEventProcessor implements EventProcessor {
  final SentryFlutterOptions _options;

  ScreenshotEventProcessor(this._options);

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

    final bytes = await SentryScreenshotWidget.captureScreenshot(_options);
    if (bytes != null) {
      hint.screenshot = SentryAttachment.fromScreenshotData(bytes);
    }
    return event;
  }
}
