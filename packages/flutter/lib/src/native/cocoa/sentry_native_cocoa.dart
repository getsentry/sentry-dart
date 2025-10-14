import 'dart:async';
import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'package:objective_c/objective_c.dart';

import '../../../sentry_flutter.dart';
import '../../replay/replay_config.dart';
import '../sentry_native_channel.dart';
import 'binding.dart' as cocoa;
import 'cocoa_replay_recorder.dart';
import 'cocoa_envelope_sender.dart';

@internal
class SentryNativeCocoa extends SentryNativeChannel {
  CocoaReplayRecorder? _replayRecorder;
  CocoaEnvelopeSender? _envelopeSender;
  SentryId? _replayId;

  SentryNativeCocoa(super.options);

  @override
  bool get supportsReplay => options.platform.isIOS;

  @override
  Future<void> init(Hub hub) async {
    // We only need these when replay is enabled (session or error capture)
    // so let's set it up conditionally. This allows Dart to trim the code.
    if (options.replay.isEnabled) {
      channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'captureReplayScreenshot':
            _replayRecorder ??= CocoaReplayRecorder(options);

            final replayId = call.arguments['replayId'] == null
                ? null
                : SentryId.fromId(call.arguments['replayId'] as String);

            if (_replayId != replayId) {
              _replayId = replayId;
              hub.configureScope((s) {
                // ignore: invalid_use_of_internal_member
                s.replayId = replayId;
              });
            }

            return _replayRecorder!.captureScreenshot();
          default:
            throw UnimplementedError('Method ${call.method} not implemented');
        }
      });
    }

    _envelopeSender = CocoaEnvelopeSender(options);
    await _envelopeSender?.start();

    return super.init(hub);
  }

  @override
  Future<void> close() async {
    await _envelopeSender?.close();
    return super.close();
  }

  @override
  FutureOr<void> captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException) {
    _envelopeSender?.captureEnvelope(envelopeData);
  }

  @override
  FutureOr<List<DebugImage>?> loadDebugImages(SentryStackTrace stackTrace) {
    try {
      final instructionAddressSet = stackTrace.frames
          .map((frame) => frame.instructionAddr)
          .nonNulls
          .toSet()
          .toNSSet();

      // NOTE: when instructionAddressSet is empty, loadDebugImages will return
      // all debug images as fallback.
      final debugImages =
          cocoa.SentryFlutterPlugin.loadDebugImages(instructionAddressSet)
              .toDartList()
              .map<Map<String, dynamic>>(
                  (e) => castFfiMap(e as Map<Object?, Object?>))
              .map<DebugImage>(DebugImage.fromJson)
              .toList(growable: false);
      return debugImages;
    } catch (exception, stackTrace) {
      options.log(SentryLevel.error, 'FFI: Failed to load debug images',
          exception: exception, stackTrace: stackTrace);

      if (options.automatedTestMode) {
        rethrow;
      }
    }
    return null;
  }

  void printWrapped(String text) {
    final pattern = new RegExp('.{1,800}'); // 800 is the size of each chunk
    pattern.allMatches(text).forEach((match) => print(match.group(0)));
  }

  @override
  FutureOr<Map<String, dynamic>?> loadContexts() {
    try {
      return cocoa.SentryFlutterPlugin.loadContexts()
          .toDartMap()
          .map((key, value) => MapEntry(key.toString(), value));
    } catch (exception, stackTrace) {
      options.log(SentryLevel.error, 'FFI: Failed to load contexts',
          exception: exception, stackTrace: stackTrace);

      if (options.automatedTestMode) {
        rethrow;
      }
      return null;
    }
  }

  // Recursively convert any int 0/1 values to bool to compensate for
  // Objective-C NSNumber -> Dart conversions that lose boolean typing.
  dynamic _normalizeObjectiveCBools(dynamic value) {
    if (value is Map) {
      final result = <String, dynamic>{};
      value.forEach((k, v) {
        final key = k is String ? k : k.toString();
        result[key] = _normalizeObjectiveCBools(v);
      });
      return result;
    }
    if (value is List) {
      return value.map(_normalizeObjectiveCBools).toList(growable: false);
    }
    if (value is int) {
      if (value == 0) return false;
      if (value == 1) return true;
    }
    return value;
  }

  // Casts a loosely typed FFI map into a standard Dart map with string keys.
  Map<String, dynamic> castFfiMap(Map<Object?, Object?> map) {
    final result = <String, dynamic>{};
    map.forEach((key, value) {
      result[key?.toString() ?? ''] = value;
    });
    return result;
  }

  @override
  FutureOr<void> setReplayConfig(ReplayConfig config) {
    // Note: unused on iOS.
  }

  @override
  int? startProfiler(SentryId traceId) => tryCatchSync(
        'startProfiler',
        () {
          final sentryId$1 = cocoa.SentryId$1.alloc()
              .initWithUUIDString(NSString(traceId.toString()));

          final sentryId = cocoa.SentryId.castFromPointer(
            sentryId$1.ref.pointer,
            retain: true,
            release: true,
          );

          final startTime =
              cocoa.PrivateSentrySDKOnly.startProfilerForTrace(sentryId);
          return startTime;
        },
      );
}
