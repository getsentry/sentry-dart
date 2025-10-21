import 'dart:async';
import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'package:objective_c/objective_c.dart';

import '../../../sentry_flutter.dart';
import '../../replay/replay_config.dart';
import '../native_app_start.dart';
import '../sentry_native_channel.dart';
import '../utils/data_normalizer.dart';
import '../utils/utf8_json.dart';
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

      // Use a single FFI call to get images as UTF-8 encoded JSON instead of
      // making multiple FFI calls to convert each object individually. This approach
      // is significantly faster because images can be large.
      // Local benchmarks show this method is ~4x faster than the alternative
      // approach of converting FFI objects to Dart objects one by one.

      // NOTE: when instructionAddressSet is empty, loadDebugImagesAsBytes will return
      // all debug images as fallback.
      final imagesUtf8JsonBytes =
          cocoa.SentryFlutterPlugin.loadDebugImagesAsBytes(
              instructionAddressSet);
      if (imagesUtf8JsonBytes == null) return null;

      final debugImageMaps =
          decodeUtf8JsonListOfMaps(imagesUtf8JsonBytes.toList());
      return debugImageMaps.map(DebugImage.fromJson).toList(growable: false);
    } catch (exception, stackTrace) {
      options.log(SentryLevel.error, 'FFI: Failed to load debug images',
          exception: exception, stackTrace: stackTrace);

      if (options.automatedTestMode) {
        rethrow;
      }
    }
    return null;
  }

  @override
  FutureOr<Map<String, dynamic>?> loadContexts() {
    try {
      // Use a single FFI call to get contexts as UTF-8 encoded JSON instead of
      // making multiple FFI calls to convert each object individually. This approach
      // is significantly faster because contexts can be large and contain many nested
      // objects. Local benchmarks show this method is ~4x faster than the alternative
      // approach of converting FFI objects to Dart objects one by one.
      final contextsUtf8JsonBytes =
          cocoa.SentryFlutterPlugin.loadContextsAsBytes();
      if (contextsUtf8JsonBytes == null) return null;

      final contexts = decodeUtf8JsonMap(contextsUtf8JsonBytes.toList());
      return contexts;
    } catch (exception, stackTrace) {
      options.log(SentryLevel.error, 'FFI: Failed to load contexts',
          exception: exception, stackTrace: stackTrace);

      if (options.automatedTestMode) {
        rethrow;
      }
      return null;
    }
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

  @override
  int? displayRefreshRate() => tryCatchSync(
        'displayRefreshRate',
        () {
          final refreshRate = cocoa.SentryFlutterPlugin.getDisplayRefreshRate();
          return refreshRate?.intValue;
        },
      );

  @override
  NativeAppStart? fetchNativeAppStart() => tryCatchSync(
        'fetchNativeAppStart',
        () {
          final appStartUtf8JsonBytes =
              cocoa.SentryFlutterPlugin.fetchNativeAppStartAsBytes();
          if (appStartUtf8JsonBytes == null) return null;

          final json = decodeUtf8JsonMap(appStartUtf8JsonBytes.toList());
          return NativeAppStart.fromJson(json);
        },
      );

  @override
  void addBreadcrumb(Breadcrumb breadcrumb) =>
      tryCatchSync('addBreadcrumb', () {
        final nativeBreadcrumb =
            cocoa.PrivateSentrySDKOnly.breadcrumbWithDictionary(
                _deepConvertMapNonNull(breadcrumb.toJson()).toNSDictionary());
        cocoa.SentrySDK.addBreadcrumb(nativeBreadcrumb);
      });

  @override
  void clearBreadcrumbs() => tryCatchSync('clearBreadcrumbs', () {
        cocoa.SentrySDK.configureScope(
            cocoa.ObjCBlock_ffiVoid_SentryScope.fromFunction(
                (cocoa.SentryScope scope) {
          scope.clearBreadcrumbs();
        }));
      });

  @override
  void nativeCrash() => cocoa.SentrySDK.crash();

  @override
  void pauseAppHangTracking() => tryCatchSync('pauseAppHangTracking', () {
        cocoa.SentrySDK.pauseAppHangTracking();
      });

  @override
  void resumeAppHangTracking() => tryCatchSync('resumeAppHangTracking', () {
        cocoa.SentrySDK.resumeAppHangTracking();
      });

  @override
  void setUser(SentryUser? user) => tryCatchSync('setUser', () {
        if (user == null) {
          cocoa.SentrySDK.setUser(null);
        } else {
          final dictionary =
              _deepConvertMapNonNull(user.toJson()).toNSDictionary();
          final cUser =
              cocoa.PrivateSentrySDKOnly.userWithDictionary(dictionary);
          cocoa.SentrySDK.setUser(cUser);
        }
      });

  @override
  void setContexts(String key, dynamic value) =>
      tryCatchSync('setContexts', () {
        NSDictionary? dictionary;

        final normalizedValue = normalize(value);
        dictionary = switch (normalizedValue) {
          Map<String, dynamic> m => _deepConvertMapNonNull(m).toNSDictionary(),
          bool b => NSDictionary.fromEntries([
              MapEntry(
                  'value'.toNSString(), b ? 1.toNSNumber() : 0.toNSNumber())
            ]),
          Object o => NSDictionary.fromEntries(
              [MapEntry('value'.toNSString(), toObjCObject(o))]),
          _ => null
        };

        cocoa.SentrySDK.configureScope(
            cocoa.ObjCBlock_ffiVoid_SentryScope.fromFunction(
                (cocoa.SentryScope scope) {
          if (dictionary != null) {
            scope.setContextValue(dictionary, forKey: key.toNSString());
          }
        }));
      });

  @override
  void removeContexts(String key) => tryCatchSync('removeContexts', () {
        cocoa.SentrySDK.configureScope(
            cocoa.ObjCBlock_ffiVoid_SentryScope.fromFunction(
                (cocoa.SentryScope scope) {
          scope.removeContextForKey(key.toNSString());
        }));
      });

  @override
  void setExtra(String key, dynamic value) => tryCatchSync('setExtra', () {
        ObjCObjectBase? cValue = switch (value) {
          Map<String, dynamic> m => _deepConvertMapNonNull(m).toNSDictionary(),
          bool b => b ? 1.toNSNumber() : 0.toNSNumber(),
          Object o => toObjCObject(o),
          _ => null
        };

        cocoa.SentrySDK.configureScope(
            cocoa.ObjCBlock_ffiVoid_SentryScope.fromFunction(
                (cocoa.SentryScope scope) {
          if (cValue != null) {
            scope.setExtraValue(cValue, forKey: key.toNSString());
          }
        }));
      });

  @override
  void removeExtra(String key) => tryCatchSync('removeExtra', () {
        cocoa.SentrySDK.configureScope(
            cocoa.ObjCBlock_ffiVoid_SentryScope.fromFunction(
                (cocoa.SentryScope scope) {
          scope.removeExtraForKey(key.toNSString());
        }));
      });

  @override
  void setTag(String key, String value) => tryCatchSync('setTag', () {
        cocoa.SentrySDK.configureScope(
            cocoa.ObjCBlock_ffiVoid_SentryScope.fromFunction(
                (cocoa.SentryScope scope) {
          scope.setTagValue(value.toNSString(), forKey: key.toNSString());
        }));
      });

  @override
  void removeTag(String key) => tryCatchSync('removeTag', () {
        cocoa.SentrySDK.configureScope(
            cocoa.ObjCBlock_ffiVoid_SentryScope.fromFunction(
                (cocoa.SentryScope scope) {
          scope.removeTagForKey(key.toNSString());
        }));
      });

  @override
  SentryId captureReplay() {
    final value = cocoa.SentryFlutterPlugin.captureReplay()?.toDartString();
    if (value == null) {
      return SentryId.empty();
    }
    return SentryId.fromId(value);
  }
}

/// This map conversion is needed so we can use the toNSDictionary extension function
/// provided by the objective_c package.
Map<Object, Object> _deepConvertMapNonNull(Map<String, dynamic> input) {
  final out = <Object, Object>{};

  for (final entry in input.entries) {
    final value = entry.value;
    if (value == null) continue;

    out[entry.key] = switch (value) {
      Map<String, dynamic> m => _deepConvertMapNonNull(m),
      List<dynamic> l => [
          for (final e in l)
            if (e != null)
              e is Map<String, dynamic>
                  ? _deepConvertMapNonNull(e)
                  : e as Object
        ],
      _ => value as Object,
    };
  }

  return out;
}
