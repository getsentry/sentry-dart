import 'dart:async';
import 'dart:isolate';

import 'package:jni/jni.dart';
import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../replay/scheduled_recorder.dart';
import '../../screenshot/screenshot.dart';
import 'binding.dart' as native;

@internal
class AndroidReplayRecorder extends ScheduledScreenshotRecorder {
  _AndroidNativeReplayWorker? _worker;

  AndroidReplayRecorder(super.config, super.options) {
    super.callback = _addReplayScreenshot;
  }

  @override
  Future<void> start() async {
    final spawningWorker = _AndroidNativeReplayWorker.spawn();
    super.start();
    _worker = await spawningWorker;
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
      options.logger(
          SentryLevel.debug,
          '$logName: captured screenshot ('
          '${screenshot.width}x${screenshot.height} pixels, '
          '${data.lengthInBytes} bytes)');

      final jBuffer = JByteBuffer.fromList(data.buffer.asUint8List());
      int width = screenshot.width;
      int height = screenshot.height;

      await _worker!.nativeAddScreenshot(_WorkItem(
          timestamp: timestamp,
          jBuffer: jBuffer,
          width: width,
          height: height));
    } catch (error, stackTrace) {
      options.logger(
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
}

// Based on https://dart.dev/language/isolates#robust-ports-example
class _AndroidNativeReplayWorker {
  final SendPort _commands;
  final ReceivePort _responses;
  final Map<int, Completer<Object?>> _activeRequests = {};
  int _idCounter = 0;
  bool _closed = false;

  static Future<_AndroidNativeReplayWorker> spawn() async {
    // Create a receive port and add its initial message handler
    final initPort = RawReceivePort();
    final connection = Completer<(ReceivePort, SendPort)>.sync();
    initPort.handler = (SendPort commandPort) {
      connection.complete((
        ReceivePort.fromRawReceivePort(initPort),
        commandPort,
      ));
    };

    // Spawn the isolate.
    try {
      await Isolate.spawn(_startRemoteIsolate, (initPort.sendPort),
          debugName: 'SentryReplayRecorder');
    } on Object {
      initPort.close();
      rethrow;
    }

    final (ReceivePort receivePort, SendPort sendPort) =
        await connection.future;

    return _AndroidNativeReplayWorker._(receivePort, sendPort);
  }

  _AndroidNativeReplayWorker._(this._responses, this._commands) {
    _responses.listen(_handleResponsesFromIsolate);
  }

  Future<Object?> nativeAddScreenshot(_WorkItem item) async {
    if (_closed) throw StateError('Closed');
    final completer = Completer<Object?>.sync();
    final id = _idCounter++;
    _activeRequests[id] = completer;
    _commands.send((id, item));
    return await completer.future;
  }

  void _handleResponsesFromIsolate(dynamic message) {
    final (int id, Object? response) = message as (int, Object?);
    final completer = _activeRequests.remove(id)!;

    if (response is RemoteError) {
      completer.completeError(response);
    } else {
      completer.complete(response);
    }

    if (_closed && _activeRequests.isEmpty) _responses.close();
  }

  /// This is the actual Android native implementation, the rest is just plumbing.
  static void _handleCommandsToIsolate(
    ReceivePort receivePort,
    SendPort sendPort,
  ) {
    // Android Bitmap creation is a bit costly so we reuse it between captures.
    native.Bitmap? bitmap;

    final _nativeReplay = native.SentryFlutterPlugin$Companion(null)
        .privateSentryGetReplayIntegration()!;

    receivePort.listen((message) {
      if (message == 'shutdown') {
        receivePort.close();
        return;
      }
      final (id, item) = message as (int, _WorkItem);
      try {
        if (bitmap != null) {
          if (bitmap!.getWidth() != item.width ||
              bitmap!.getHeight() != item.height) {
            bitmap!.release();
            bitmap = null;
          }
        }

        // https://developer.android.com/reference/android/graphics/Bitmap#createBitmap(int,%20int,%20android.graphics.Bitmap.Config)
        // Note: in the currently generated API this may return null so we null-check below.
        bitmap ??= native.Bitmap.createBitmap$3(
            item.width, item.height, native.Bitmap$Config.ARGB_8888);

        try {
          bitmap?.copyPixelsFromBuffer(item.jBuffer);
        } finally {
          item.jBuffer.release();
        }

        if (bitmap != null) {
          // TODO timestamp is currently missing in onScreenshotRecorded()
          _nativeReplay.onScreenshotRecorded(bitmap!);
        }

        sendPort.send((id, null));
      } catch (e, stacktrace) {
        sendPort.send((id, RemoteError(e.toString(), stacktrace.toString())));
      }
    });
  }

  static void _startRemoteIsolate(SendPort sendPort) {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);
    _handleCommandsToIsolate(receivePort, sendPort);
  }

  void close() {
    if (!_closed) {
      _closed = true;
      _commands.send('shutdown');
      if (_activeRequests.isEmpty) _responses.close();
    }
  }
}

class _WorkItem {
  final int timestamp;
  final JByteBuffer jBuffer;
  final int width;
  final int height;

  const _WorkItem({
    required this.timestamp,
    required this.jBuffer,
    required this.width,
    required this.height,
  });
}
