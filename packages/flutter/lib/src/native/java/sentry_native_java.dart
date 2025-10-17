import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:jni/jni.dart';
import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../replay/scheduled_recorder_config.dart';
import '../native_app_start.dart';
import '../sentry_native_channel.dart';
import '../utils/data_normalizer.dart';
import '../utils/utf8_json.dart';
import 'android_envelope_sender.dart';
import 'android_replay_recorder.dart';
import 'binding.dart' as native;

@internal
class SentryNativeJava extends SentryNativeChannel {
  AndroidReplayRecorder? _replayRecorder;
  AndroidEnvelopeSender? _envelopeSender;

  SentryNativeJava(super.options);

  @override
  bool get supportsReplay => true;

  @override
  Future<void> init(Hub hub) async {
    // We only need these when replay is enabled (session or error capture)
    // so let's set it up conditionally. This allows Dart to trim the code.
    if (options.replay.isEnabled) {
      channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'ReplayRecorder.start':
            final replayId =
                SentryId.fromId(call.arguments['replayId'] as String);

            _replayRecorder = AndroidReplayRecorder.factory(options);
            await _replayRecorder!.start();
            hub.configureScope((s) {
              // ignore: invalid_use_of_internal_member
              s.replayId = replayId;
            });
            break;
          case 'ReplayRecorder.onConfigurationChanged':
            final config = ScheduledScreenshotRecorderConfig(
                width: (call.arguments['width'] as num).toDouble(),
                height: (call.arguments['height'] as num).toDouble(),
                frameRate: call.arguments['frameRate'] as int);

            await _replayRecorder?.onConfigurationChanged(config);
            break;
          case 'ReplayRecorder.stop':
            hub.configureScope((s) {
              // ignore: invalid_use_of_internal_member
              s.replayId = null;
            });

            final future = _replayRecorder?.stop();
            _replayRecorder = null;
            await future;

            break;
          case 'ReplayRecorder.pause':
            await _replayRecorder?.pause();
            break;
          case 'ReplayRecorder.resume':
            await _replayRecorder?.resume();
            break;
          case 'ReplayRecorder.reset':
            // ignored
            break;
          default:
            throw UnimplementedError('Method ${call.method} not implemented');
        }
      });
    }

    _envelopeSender = AndroidEnvelopeSender.factory(options);
    await _envelopeSender?.start();

    return super.init(hub);
  }

  @override
  FutureOr<void> captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException) {
    _envelopeSender?.captureEnvelope(envelopeData, containsUnhandledException);
  }

  @override
  FutureOr<List<DebugImage>?> loadDebugImages(SentryStackTrace stackTrace) {
    JSet<JString>? instructionAddressSet;
    Set<JString>? instructionAddressJStrings;
    JByteArray? imagesUtf8JsonBytes;

    try {
      instructionAddressJStrings = stackTrace.frames
          .map((f) => f.instructionAddr)
          .nonNulls
          .map((s) => s.toJString())
          .toSet();

      instructionAddressSet = instructionAddressJStrings.nonNulls
          .cast<JString>()
          .toJSet(JString.type);

      // Use a single JNI call to get images as UTF-8 encoded JSON instead of
      // making multiple JNI calls to convert each object individually. This approach
      // is significantly faster because images can be large.
      // Local benchmarks show this method is ~4x faster than the alternative
      // approach of converting JNI objects to Dart objects one by one.

      // NOTE: when instructionAddressSet is empty, loadDebugImagesAsBytes will return
      // all debug images as fallback.
      imagesUtf8JsonBytes = native.SentryFlutterPlugin.Companion
          .loadDebugImagesAsBytes(instructionAddressSet);
      if (imagesUtf8JsonBytes == null) return null;

      final byteRange =
          imagesUtf8JsonBytes.getRange(0, imagesUtf8JsonBytes.length);
      final bytes = Uint8List.view(
          byteRange.buffer, byteRange.offsetInBytes, byteRange.length);
      final debugImageMaps = decodeUtf8JsonListOfMaps(bytes);
      return debugImageMaps.map(DebugImage.fromJson).toList(growable: false);
    } catch (exception, stackTrace) {
      options.log(SentryLevel.error, 'JNI: Failed to load debug images',
          exception: exception, stackTrace: stackTrace);
      if (options.automatedTestMode) {
        rethrow;
      }
    } finally {
      // Release JNI refs
      for (final js in instructionAddressJStrings ?? const <JString>[]) {
        js.release();
      }
      instructionAddressSet?.release();
      imagesUtf8JsonBytes?.release();
    }

    return null;
  }

  @override
  FutureOr<Map<String, dynamic>?> loadContexts() {
    JByteArray? contextsUtf8JsonBytes;

    try {
      // Use a single JNI call to get contexts as UTF-8 encoded JSON instead of
      // making multiple JNI calls to convert each object individually. This approach
      // is significantly faster because contexts can be large and contain many nested
      // objects. Local benchmarks show this method is ~4x faster than the alternative
      // approach of converting JNI objects to Dart objects one by one.
      contextsUtf8JsonBytes =
          native.SentryFlutterPlugin.Companion.loadContextsAsBytes();
      if (contextsUtf8JsonBytes == null) return null;

      final byteRange =
          contextsUtf8JsonBytes.getRange(0, contextsUtf8JsonBytes.length);
      final bytes = Uint8List.view(
          byteRange.buffer, byteRange.offsetInBytes, byteRange.length);
      return decodeUtf8JsonMap(bytes);
    } catch (exception, stackTrace) {
      options.log(SentryLevel.error, 'JNI: Failed to load contexts',
          exception: exception, stackTrace: stackTrace);
      if (options.automatedTestMode) {
        rethrow;
      }
    } finally {
      contextsUtf8JsonBytes?.release();
    }

    return null;
  }

  @override
  int? displayRefreshRate() => tryCatchSync('displayRefreshRate', () {
        return native.SentryFlutterPlugin.Companion
            .getDisplayRefreshRate()
            ?.intValue();
      });

  @override
  NativeAppStart? fetchNativeAppStart() {
    JByteArray? appStartUtf8JsonBytes;

    return tryCatchSync('fetchNativeAppStart', () {
      appStartUtf8JsonBytes =
          native.SentryFlutterPlugin.Companion.fetchNativeAppStartAsBytes();
      if (appStartUtf8JsonBytes == null) return null;

      final byteRange =
          appStartUtf8JsonBytes!.getRange(0, appStartUtf8JsonBytes!.length);
      final bytes = Uint8List.view(
          byteRange.buffer, byteRange.offsetInBytes, byteRange.length);
      final appStartMap = decodeUtf8JsonMap(bytes);
      return NativeAppStart.fromJson(appStartMap);
    }, finallyFn: () {
      appStartUtf8JsonBytes?.release();
    });
  }

  @override
  void nativeCrash() => native.SentryFlutterPlugin.Companion.crash();

  @override
  void pauseAppHangTracking() {
    assert(false, 'pauseAppHangTracking is not supported on Android.');
  }

  @override
  void resumeAppHangTracking() {
    assert(false, 'resumeAppHangTracking is not supported on Android.');
  }

  @override
  Future<void> close() async {
    await _replayRecorder?.stop();
    await _envelopeSender?.close();
    return super.close();
  }

  @override
  void addBreadcrumb(Breadcrumb breadcrumb) {
    JByteArray? breadcrumbBytes;

    tryCatchSync('addBreadcrumb', () {
      final jsonString = json.encode(breadcrumb.toJson());
      final bytes = utf8.encode(jsonString);
      breadcrumbBytes = JByteArray.from(bytes);

      native.SentryFlutterPlugin.Companion
          .addBreadcrumbAsBytes(breadcrumbBytes!);
    }, finallyFn: () {
      breadcrumbBytes?.release();
    });
  }

  @override
  void clearBreadcrumbs() => tryCatchSync('clearBreadcrumbs', () {
        native.Sentry.clearBreadcrumbs();
      });
}
