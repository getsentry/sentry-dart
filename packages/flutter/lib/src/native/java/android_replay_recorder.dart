import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show PlatformDispatcher;

import 'package:jni/jni.dart';
import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../isolate/isolate_worker.dart';
import '../../replay/scheduled_recorder.dart';
import '../../screen_capture/screenshot.dart';
import '../../utils/internal_logger.dart';
import 'binding.dart' as native;

// Only the host-side lifecycle is unit-tested. The worker-side JNI calls are
// not, because mocking them is cumbersome, see
// https://github.com/dart-lang/native/issues/1794
@internal
class AndroidReplayRecorder extends ScheduledScreenshotRecorder {
  final WorkerConfig _config;
  final SpawnWorkerFn _spawn;
  final ArmWorkerExitFn _armExit;

  /// The engine's exit token, see [Worker.closeWithExitToken]. Null if the
  /// engine has no id: a worker that [stop] closes is then free to exit
  /// after its engine is gone.
  final int? _exitToken;
  Worker? _worker;
  // Incremented by every start(), stop() and closeForEngineDetach(), so that
  // a start() can tell, once its spawn has completed, whether a later one of
  // them has superseded it.
  int _lifecycleGeneration = 0;

  /// The token of the engine detach, once the engine is detaching.
  int? _detachToken;

  @internal // visible for testing, used by SentryNativeJava
  static AndroidReplayRecorder Function(SentryFlutterOptions) factory =
      AndroidReplayRecorder.new;

  @visibleForTesting
  void Function()? onScreenshotAddedForTest;

  AndroidReplayRecorder(
    super.options, {
    SpawnWorkerFn? spawn,
    ArmWorkerExitFn? armExit,
    int? exitToken,
  }) : _config = WorkerConfig(
         debugName: 'SentryAndroidReplayRecorder',
         debug: options.debug,
         diagnosticLevel: options.diagnosticLevel,
         automatedTestMode: options.automatedTestMode,
       ),
       _spawn = spawn ?? spawnWorker,
       _armExit = armExit ?? native.SentryFlutterPlugin.armWorkerExit,
       _exitToken = exitToken ?? PlatformDispatcher.instance.engineId {
    super.callback = (screenshot, isNewlyCaptured) {
      onScreenshotAddedForTest?.call();
      return _addReplayScreenshot(screenshot, isNewlyCaptured);
    };
  }

  @override
  Future<void> start() async {
    // The engine is going away. A worker spawned now would be closed without
    // the detach token by a later stop(), so it could exit after the engine
    // is gone.
    if (_detachToken != null) return;
    if (_worker != null) return;
    final generation = ++_lifecycleGeneration;
    final worker = await _spawn(_config, _entryPoint);
    // stop(), closeForEngineDetach() or another start() can run while the
    // spawn is in flight. None of them sees this worker, so it has to be
    // closed here, or it outlives the recorder and keeps its isolate group
    // alive.
    if (generation != _lifecycleGeneration) {
      _close(worker);
      return;
    }
    _worker = worker;
    await super.start();
  }

  /// Closes [worker] with the engine's token, so that the engine can detach
  /// while the worker is still handling its queue. Without a token the
  /// worker exits whenever it is done.
  void _close(Worker worker) {
    final token = _detachToken ?? _exitToken;
    if (token == null) {
      worker.close();
    } else {
      worker.closeWithExitToken(token, _armExit);
    }
  }

  /// Stops the worker because its engine is about to be destroyed, see
  /// [Worker.closeWithExitToken]. Must stay synchronous.
  ///
  /// A worker that [stop] already closed is covered by the token it was
  /// closed with. A worker that is still spawning is not covered, see
  /// `AndroidCoreWorker.closeForEngineDetach`.
  void closeForEngineDetach(int token) {
    // Also set when stop() ran first: start() needs the token for a worker
    // that was still spawning when stop() ran.
    _detachToken = token;
    // Supersedes a start() whose spawn is still in flight, like stop() does.
    _lifecycleGeneration++;
    final worker = _worker;
    _worker = null;
    // Stops new captures. The scheduler winds down asynchronously, which
    // nothing can wait for at this point.
    unawaited(super.stop());
    worker?.closeWithExitToken(token, _armExit);
  }

  @override
  Future<void> stop() async {
    _lifecycleGeneration++;
    await super.stop();
    final worker = _worker;
    try {
      await worker?.request(const _CloseRequest());
    } catch (error, stackTrace) {
      internalLogger.error(
        '$logName: native call `close` failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (options.automatedTestMode) {
        rethrow;
      }
    } finally {
      if (worker != null) _close(worker);
      _worker = null;
    }
  }

  Future<void> _addReplayScreenshot(
    Screenshot screenshot,
    bool isNewlyCaptured,
  ) async {
    final timestamp = screenshot.timestamp.millisecondsSinceEpoch;

    try {
      final data = await screenshot.rawRgbaData;
      internalLogger.debug(
        '$logName: captured screenshot ('
        '${screenshot.width}x${screenshot.height} pixels, '
        '${data.lengthInBytes} bytes)',
      );

      // closeForEngineDetach() can run while the screenshot is being encoded,
      // and so can stop(): once it stopped waiting for this capture, the
      // worker is gone as well.
      final worker = _worker;
      if (worker == null) return;
      await worker.request(
        _WorkItem(
          timestamp: timestamp,
          // Screenshots are megabytes at 1 fps. Sending the bytes as a
          // TransferableTypedData hands ownership to the worker instead of
          // paying a full copy through the port on every frame.
          data: TransferableTypedData.fromList([data]),
          width: screenshot.width,
          height: screenshot.height,
        ),
      );
    } catch (error, stackTrace) {
      internalLogger.error(
        '$logName: native call `addReplayScreenshot` failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (options.automatedTestMode) {
        rethrow;
      }
    }
  }

  static void _entryPoint((SendPort, WorkerConfig) init) {
    final (host, config) = init;
    runWorker(
      config,
      host,
      _AndroidReplayHandler(config),
      requestExit: native.SentryFlutterPlugin.requestWorkerExit,
    );
  }
}

class _AndroidReplayHandler extends WorkerHandler {
  final WorkerConfig _config;
  // Android Bitmap creation is a bit costly so we reuse it between captures.
  native.Bitmap? _bitmap;
  native.ReplayIntegration? _nativeReplay;

  _AndroidReplayHandler(this._config);

  // An engine detach closes the worker without the _CloseRequest that stop()
  // sends, so the native references are released here as well.
  @override
  void onShutdown() => _releaseNativeRefs();

  @override
  FutureOr<void> onMessage(Object? message) {
    internalLogger.warning(
      '${_config.debugName}: Unexpected fire-and-forget message: $message',
    );
  }

  @override
  FutureOr<Object?> onRequest(Object? payload) {
    if (payload is _CloseRequest) {
      _releaseNativeRefs();
      return null;
    }

    if (payload is! _WorkItem) {
      internalLogger.warning(
        '${_config.debugName}: Unexpected payload type: $payload',
      );
      return null;
    }

    final item = payload;
    JByteBuffer? jBuffer;
    native.Bitmap$Config? bitmapConfig;

    try {
      var bitmap = _bitmap;
      if (bitmap != null) {
        if (bitmap.width != item.width || bitmap.height != item.height) {
          _releaseBitmap();
          bitmap = null;
        }
      }

      if (bitmap == null) {
        // https://developer.android.com/reference/android/graphics/Bitmap#createBitmap(int,%20int,%20android.graphics.Bitmap.Config)
        // Note: while the generated API is nullable, the docs say the returned value cannot be null..
        bitmapConfig = native.Bitmap$Config.ARGB_8888;
        final newBitmap = native.Bitmap.createBitmap$10(
          item.width,
          item.height,
          bitmapConfig,
        );
        if (newBitmap == null) {
          internalLogger.error('Failed to create replay bitmap');
          return null;
        }
        _bitmap = newBitmap;
        bitmap = newBitmap;
      }

      jBuffer = JByteBuffer.fromList(item.data.materialize().asUint8List());
      bitmap.copyPixelsFromBuffer(jBuffer);

      // TODO timestamp is currently missing in onScreenshotRecorded()
      _nativeReplay ??=
          native.SentryFlutterPlugin.privateSentryGetReplayIntegration();
      _nativeReplay?.onScreenshotRecorded(bitmap);

      return null;
    } catch (exception, stackTrace) {
      internalLogger.error(
        'Failed to add replay screenshot',
        error: exception,
        stackTrace: stackTrace,
      );
      if (_config.automatedTestMode) {
        rethrow;
      }
      return null;
    } finally {
      bitmapConfig?.release();
      jBuffer?.release();
    }
  }

  void _releaseNativeRefs() {
    _releaseBitmap();
    _nativeReplay?.release();
    _nativeReplay = null;
  }

  void _releaseBitmap() {
    _bitmap?.release();
    _bitmap = null;
  }
}

class _CloseRequest {
  const _CloseRequest();
}

class _WorkItem {
  final int timestamp;
  final TransferableTypedData data;
  final int width;
  final int height;

  const _WorkItem({
    required this.timestamp,
    required this.data,
    required this.width,
    required this.height,
  });
}
