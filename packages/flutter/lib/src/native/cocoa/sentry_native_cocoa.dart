import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'package:objective_c/objective_c.dart';
import 'package:objective_c/objective_c.dart' as objc
    show ObjCBlock, ObjCObject;

import '../../../sentry_flutter.dart';
import '../../replay/replay_config.dart';
import '../native_app_start.dart';
import '../sentry_native_channel.dart';
import '../utils/data_normalizer.dart';
import '../utils/utf8_json.dart';
import 'binding.dart' as cocoa;
import 'cocoa_replay_recorder.dart';
import 'cocoa_envelope_sender.dart';

part 'sentry_native_cocoa_init.dart';

@internal
class SentryNativeCocoa extends SentryNativeChannel {
  CocoaReplayRecorder? _replayRecorder;
  CocoaEnvelopeSender? _envelopeSender;
  SentryId? _replayId;

  SentryNativeCocoa(super.options);

  @override
  bool get supportsReplay => options.platform.isIOS;

  @override
  SentryId? get replayId => _replayId;

  @visibleForTesting
  CocoaReplayRecorder? get testRecorder => _replayRecorder;

  @override
  Future<void> init(Hub hub) async {
    initSentryCocoa(hub: hub, options: options, owner: this);

    _envelopeSender = CocoaEnvelopeSender(options);
    await _envelopeSender?.start();
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
          final sentryId$1 = cocoa.SentryId.alloc()
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
                _dartToNSDictionary(breadcrumb.toJson()));
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
          final dictionary = _dartToNSDictionary(user.toJson());
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
          Map<String, dynamic> m => _dartToNSDictionary(m),
          Object o => NSDictionary.fromEntries(
              [MapEntry('value'.toNSString(), _dartToNSObject(o))]),
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
  void setExtra(String key, dynamic value) => tryCatchSync('setExtra', () {
        if (value == null) return;

        cocoa.SentrySDK.configureScope(
            cocoa.ObjCBlock_ffiVoid_SentryScope.fromFunction(
                (cocoa.SentryScope scope) {
          scope.setExtraValue(_dartToNSObject(value as Object),
              forKey: key.toNSString());
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
  SentryId captureReplay() =>
      tryCatchSync('captureReplay', () {
        final value = cocoa.SentryFlutterPlugin.captureReplay()?.toDartString();
        SentryId id;
        if (value == null) {
          id = SentryId.empty();
        } else {
          id = SentryId.fromId(value);
        }
        _replayId = id;
        return id;
      }) ??
      SentryId.empty();
}

// The default conversion does not handle bool so we will add it ourselves
final ObjCObjectBase Function(Object) _defaultObjcConverter = (obj) {
  return switch (obj) {
    bool b => NSNumberCreation.numberWithBool(b),
    _ => toObjCObject(obj)
  };
};

NSDictionary _dartToNSDictionary(Map<String, dynamic> json) {
  return _deepConvertMapNonNull(json)
      .toNSDictionary(convertOther: _defaultObjcConverter);
}

NSArray _dartToNSArray(List<dynamic> list) {
  return _deepConvertListNonNull(list)
      .toNSArray(convertOther: _defaultObjcConverter);
}

ObjCObjectBase _dartToNSObject(Object value) {
  return switch (value) {
    Map<String, dynamic> m => _dartToNSDictionary(m),
    List<dynamic> l => _dartToNSArray(l),
    _ => toObjCObject(value, convertOther: _defaultObjcConverter)
  };
}

List<Object> _deepConvertListNonNull(List<dynamic> list) => [
      for (final e in list)
        if (e case Map<String, dynamic> m)
          _deepConvertMapNonNull(m)
        else if (e case List<dynamic> l)
          _deepConvertListNonNull(l)
        else if (e case Object o)
          o,
    ];

/// This map conversion is needed so we can use the toNSDictionary extension function
/// provided by the objective_c package.
Map<Object, Object> _deepConvertMapNonNull(Map<String, dynamic> input) {
  final out = <Object, Object>{};

  for (final entry in input.entries) {
    final value = entry.value;
    if (value == null) continue;

    out[entry.key] = switch (value) {
      Map<String, dynamic> m => _deepConvertMapNonNull(m),
      List<dynamic> l => _deepConvertListNonNull(l),
      _ => value as Object,
    };
  }

  return out;
}
