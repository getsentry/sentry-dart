import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:jni/jni.dart';
import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../isolate/isolate_worker.dart';
import '../../replay/scheduled_recorder.dart';
import '../../screenshot/screenshot.dart';
import '../../utils/debug_logger.dart';
import 'binding.dart' as native;

// Note, this is currently not unit-tested because mocking JNI calls is
// cumbersome, see https://github.com/dart-lang/native/issues/1794
@internal
class AndroidReplayRecorder extends ScheduledScreenshotRecorder {
  final WorkerConfig _config;
  final SpawnWorkerFn _spawn;
  Worker? _worker;

  @internal // visible for testing, used by SentryNativeJava
  static AndroidReplayRecorder Function(SentryFlutterOptions) factory =
      AndroidReplayRecorder.new;

  @visibleForTesting
  void Function()? onScreenshotAddedForTest;

  AndroidReplayRecorder(super.options, {SpawnWorkerFn? spawn})
      : _config = WorkerConfig(
          debugName: 'SentryAndroidReplayRecorder',
          debug: options.debug,
          diagnosticLevel: options.diagnosticLevel,
          automatedTestMode: options.automatedTestMode,
        ),
        _spawn = spawn ?? spawnWorker {
    super.callback = (screenshot, isNewlyCaptured) {
      onScreenshotAddedForTest?.call();
      return _addReplayScreenshot(screenshot, isNewlyCaptured);
    };
  }

  @override
  Future<void> start() async {
    if (_worker != null) return;
    _worker = await _spawn(_config, _entryPoint);
    await super.start();
  }

  @override
  Future<void> stop() async {
    await super.stop();
    _worker?.close();
    _worker = null;
  }

  Future<void> _addReplayScreenshot(
      Screenshot screenshot, bool isNewlyCaptured) async {
    final timestamp = screenshot.timestamp.millisecondsSinceEpoch;

    try {
      final data = await screenshot.rawRgbaData;
      options.log(
          SentryLevel.debug,
          '$logName: captured screenshot ('
          '${screenshot.width}x${screenshot.height} pixels, '
          '${data.lengthInBytes} bytes)');

      await _worker!.request(_WorkItem(
        timestamp: timestamp,
        data: data.buffer.asUint8List(),
        width: screenshot.width,
        height: screenshot.height,
      ));
    } catch (error, stackTrace) {
      options.log(
        SentryLevel.error,
        '$logName: native call `addReplayScreenshot` failed',
        exception: error,
        stackTrace: stackTrace,
      );
      if (options.automatedTestMode) {
        rethrow;
      }
    }
  }

  static void _entryPoint((SendPort, WorkerConfig) init) {
    final (host, config) = init;
    runWorker(config, host, _AndroidReplayHandler(config));
  }
}

class _AndroidReplayHandler extends WorkerHandler {
  final WorkerConfig _config;
  // Android Bitmap creation is a bit costly so we reuse it between captures.
  native.Bitmap? _bitmap;
  late final native.ReplayIntegration _nativeReplay;

  _AndroidReplayHandler(this._config) {
    _nativeReplay =
        native.SentryFlutterPlugin.privateSentryGetReplayIntegration()!;
  }

  @override
  FutureOr<void> onMessage(Object? message) {
    debugLogger.warning('Unexpected fire-and-forget message: $message');
  }

  @override
  FutureOr<Object?> onRequest(Object? payload) {
    if (payload is! _WorkItem) {
      debugLogger.warning('Unexpected payload type: $payload');
      return null;
    }

    final item = payload;
    JByteBuffer? jBuffer;

    try {
      if (_bitmap != null) {
        if (_bitmap!.getWidth() != item.width ||
            _bitmap!.getHeight() != item.height) {
          _bitmap!.release();
          _bitmap = null;
        }
      }

      // https://developer.android.com/reference/android/graphics/Bitmap#createBitmap(int,%20int,%20android.graphics.Bitmap.Config)
      // Note: while the generated API is nullable, the docs say the returned value cannot be null..
      _bitmap ??= native.Bitmap.createBitmap$3(
          item.width, item.height, native.Bitmap$Config.ARGB_8888);

      jBuffer = JByteBuffer.fromList(item.data);
      _bitmap!.copyPixelsFromBuffer(jBuffer);

      // TODO timestamp is currently missing in onScreenshotRecorded()
      _nativeReplay.onScreenshotRecorded(_bitmap!);

      return null;
    } catch (exception, stackTrace) {
      debugLogger.error('Failed to add replay screenshot',
          error: exception, stackTrace: stackTrace);
      if (_config.automatedTestMode) {
        rethrow;
      }
      return null;
    } finally {
      jBuffer?.release();
    }
  }
}

class _WorkItem {
  final int timestamp;
  final Uint8List data;
  final int width;
  final int height;

  const _WorkItem({
    required this.timestamp,
    required this.data,
    required this.width,
    required this.height,
  });
}
