import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../event_processor/replay_event_processor.dart';
import '../../replay/scheduled_recorder.dart';
import '../../replay/recorder_config.dart';
import '../sentry_native_channel.dart';

// Note: currently this doesn't do anything. Later, it shall be used with
// generated JNI bindings. See https://github.com/getsentry/sentry-dart/issues/1444
@internal
class SentryNativeJava extends SentryNativeChannel {
  ScheduledScreenshotRecorder? _replayRecorder;
  String? _replayCacheDir;
  _IdleFrameFiller? _idleFrameFiller;
  SentryNativeJava(super.options);

  @override
  Future<void> init(Hub hub) async {
    // We only need these when replay is enabled (session or error capture)
    // so let's set it up conditionally. This allows Dart to trim the code.
    if (options.experimental.replay.isEnabled) {
      // We only need the integration when error-replay capture is enabled.
      if ((options.experimental.replay.onErrorSampleRate ?? 0) > 0) {
        options.addEventProcessor(ReplayEventProcessor(this));
      }

      channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'ReplayRecorder.start':
            final replayId =
                SentryId.fromId(call.arguments['replayId'] as String);

            _startRecorder(
              call.arguments['directory'] as String,
              ScheduledScreenshotRecorderConfig(
                width: call.arguments['width'] as int,
                height: call.arguments['height'] as int,
                frameRate: call.arguments['frameRate'] as int,
              ),
            );

            hub.configureScope((s) {
              // ignore: invalid_use_of_internal_member
              s.replayId = replayId;
            });

            break;
          case 'ReplayRecorder.stop':
            await _stopRecorder();

            hub.configureScope((s) {
              // ignore: invalid_use_of_internal_member
              s.replayId = null;
            });

            break;
          case 'ReplayRecorder.pause':
            await _replayRecorder?.stop();
            await _idleFrameFiller?.pause();
            break;
          case 'ReplayRecorder.resume':
            _replayRecorder?.start();
            await _idleFrameFiller?.resume();
            break;
          default:
            throw UnimplementedError('Method ${call.method} not implemented');
        }
      });
    }

    return super.init(hub);
  }

  @override
  Future<void> close() async {
    await _stopRecorder();
    return super.close();
  }

  Future<void> _stopRecorder() async {
    await _replayRecorder?.stop();
    await _idleFrameFiller?.stop();
    _replayRecorder = null;
    _idleFrameFiller = null;
  }

  void _startRecorder(
      String cacheDir, ScheduledScreenshotRecorderConfig config) {
    _idleFrameFiller = _IdleFrameFiller(
        Duration(milliseconds: 1000 ~/ config.frameRate), _addReplayScreenshot);

    // Note: time measurements using a Stopwatch in a debug build:
    //     save as rawRgba (1230876 bytes): 0.257 ms  -- discarded
    //     save as PNG (25401 bytes): 43.110 ms  -- used for the final image
    //     image size: 25401 bytes
    //     save to file: 3.677 ms
    //     onScreenshotRecorded1: 1.237 ms
    //     released and exiting callback: 0.021 ms
    ScreenshotRecorderCallback callback = (image) async {
      var imageData = await image.toByteData(format: ImageByteFormat.png);
      if (imageData != null) {
        final screenshot = _Screenshot(image.width, image.height, imageData);
        await _addReplayScreenshot(screenshot);
        _idleFrameFiller?.actualFrameReceived(screenshot);
      }
    };

    _replayCacheDir = cacheDir;
    _replayRecorder = ScheduledScreenshotRecorder(config, callback, options)
      ..start();
  }

  Future<void> _addReplayScreenshot(_Screenshot screenshot) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = "$_replayCacheDir/$timestamp.png";

    options.logger(
        SentryLevel.debug,
        'Replay: Saving screenshot to $filePath ('
        '${screenshot.width}x${screenshot.height} pixels, '
        '${screenshot.data.lengthInBytes} bytes)');
    try {
      await options.fileSystem
          .file(filePath)
          .writeAsBytes(screenshot.data.buffer.asUint8List(), flush: true);

      await channel.invokeMethod(
        'addReplayScreenshot',
        {'path': filePath, 'timestamp': timestamp},
      );
    } catch (error, stackTrace) {
      options.logger(
        SentryLevel.error,
        'Native call `addReplayScreenshot` failed',
        exception: error,
        stackTrace: stackTrace,
      );
      if (options.automatedTestMode) {
        rethrow;
      }
    }
  }
}

class _Screenshot {
  final int width;
  final int height;
  final ByteData data;

  _Screenshot(this.width, this.height, this.data);
}

// Workaround for https://github.com/getsentry/sentry-java/issues/3677
// In short: when there are no postFrameCallbacks issued by Flutter (because
// there are no animations or user interactions), the replay recorder will
// need to get screenshots at a fixed frame rate. This class is responsible for
// filling the gaps between actual frames with the most recent frame.
class _IdleFrameFiller {
  final Duration _interval;
  final Future<void> Function(_Screenshot screenshot) _callback;
  bool _running = true;
  Future<void>? _scheduled;
  _Screenshot? _mostRecent;

  _IdleFrameFiller(this._interval, this._callback);

  void actualFrameReceived(_Screenshot screenshot) {
    // We store the most recent frame but only repost it when the most recent
    // one is the same instance (unchanged).
    _mostRecent = screenshot;
    // Also, the initial reposted frame will be delayed to allow actual frames
    // to cancel the reposting.
    repostLater(_interval * 1.5, screenshot);
  }

  Future<void> stop() async {
    // Clearing [_mostRecent] stops the delayed callback from posting the image.
    _mostRecent = null;
    _running = false;
    await _scheduled;
    _scheduled = null;
  }

  Future<void> pause() async {
    _running = false;
  }

  Future<void> resume() async {
    _running = true;
  }

  void repostLater(Duration delay, _Screenshot screenshot) {
    _scheduled = Future.delayed(delay, () async {
      // Only repost if the screenshot haven't changed.
      if (screenshot == _mostRecent) {
        if (_running) {
          await _callback(screenshot);
        }
        // On subsequent frames, we stick to the actual frame rate.
        repostLater(_interval, screenshot);
      }
    });
  }
}
