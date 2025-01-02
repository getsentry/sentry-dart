import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import 'recorder.dart';

/// We're facing an issue: the tree walked with visitChildElements() is out of
/// sync to what is currently rendered by RenderRepaintBoundary.toImage(),
/// even though there's no async gap between these two. This causes masks to
/// be off during repaints, e.g. when scrolling a view or when text is rendered
/// in different places between two screens. This is most easily reproducible
/// when there's no animation between the two screens.
/// For example, Spotube's Search vs Library (2nd and 3rd bottom bar buttons).
///
/// To get around this issue, we're taking two subsequent screenshots
/// (after two frames) and only actually capture a screenshot if the
/// two are exactly the same.
/// We only do these if masking is enabled.
@internal
class ScreenshotRetrier<R> {
  final SentryFlutterOptions _options;
  final ScreenshotRecorder _recorder;
  final Future<R> Function(ScreenshotPng screenshot) _callback;
  ScreenshotPng? _previousScreenshot;
  int _tries = 0;
  bool stopped = false;

  ScreenshotRetrier(this._recorder, this._options, this._callback) {
    assert(_options.screenshotRetries >= 1,
        "Cannot use ScreenshotRetrier if we cannot retry at least once.");
  }

  void ensureFrameAndAddCallback(FrameCallback callback) {
    _options.bindingUtils.instance!
      ..ensureVisualUpdate()
      ..addPostFrameCallback(callback);
  }

  Future<void> capture(Duration sinceSchedulerEpoch) {
    _tries++;
    return _recorder.capture(_onImageCaptured);
  }

  Future<void> _onImageCaptured(ScreenshotPng screenshot) async {
    if (stopped) {
      _tries = 0;
      return;
    }

    final prevScreenshot = _previousScreenshot;
    _previousScreenshot = screenshot;
    if (prevScreenshot != null && prevScreenshot.hasSameImageAs(screenshot)) {
      _tries = 0;
      await _callback(screenshot);
    } else if (_tries > _options.screenshotRetries) {
      throw Exception('Failed to capture a stable screenshot. '
          'Giving up after $_tries tries.');
    } else {
      ensureFrameAndAddCallback(capture);
    }
  }
}
