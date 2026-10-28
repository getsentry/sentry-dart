// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';
// ignore: implementation_imports
import 'package:sentry/src/utils/iterable_utils.dart';

import '../../../sentry_flutter.dart';
import '../../isolate/isolate_worker.dart';
import '../../replay/replay_config.dart';
import '../../utils/internal_logger.dart';
import '../native_app_start.dart';
import '../sentry_native_binding.dart';
import '../sentry_native_invoker.dart';
import 'binding.dart' as binding;
import 'utils.dart';

@internal
class SentryNative with SentryNativeSafeInvoker implements SentryNativeBinding {
  @override
  final SentryFlutterOptions options;

  @visibleForTesting
  static final native = binding.SentryNative(
    DynamicLibrary.open(_dynamicLibraryPath),
  );

  static String get _dynamicLibraryPath =>
      '$dynamicLibraryDirectory${Platform.isWindows ? 'sentry.dll' : 'libsentry.so'}';

  /// If the path is just the library name, the loader will look for it in
  /// the usual places for shared libraries:
  /// - on Linux in /lib and /usr/lib
  /// - on Windows in the working directory and System32
  @visibleForTesting
  static String dynamicLibraryDirectory = '';

  @visibleForTesting
  static String? crashpadPath = _getDefaultCrashpadPath();

  SentryNative(this.options);

  // Tracks whether this binding auto-initialized the native SDK, so close() -
  // which may now be called even when crash handling was never enabled, see
  // #3960 - doesn't touch the `native` binding (and so trigger its lazy
  // DynamicLibrary.open) for the first time on a binding that was never
  // initialized.
  bool _nativeSdkAutoInitialized = false;

  /// Completes once a background `sentry_init()` has returned.
  Future<void>? _pendingInit;

  void _logNotSupported(String operation) =>
      internalLogger.debug('SentryNative: $operation is not supported');

  @override
  FutureOr<void> init(Hub hub) {
    if (!options.enableNativeCrashHandling) {
      internalLogger.info('SentryNative crash handling is disabled');
    } else if (Platform.isWindows) {
      return _initInBackground();
    } else {
      tryCatchSync("init", () {
        final cOptions = createOptions(options);
        _checkInitResult(native.init(cOptions));
      });
    }
  }

  /// On Windows the root isolate runs on the platform thread, so a blocking
  /// `sentry_init()` (e.g. waiting for the Crashpad handler) freezes the UI.
  Future<void> _initInBackground() async {
    final done = Completer<void>();
    _pendingInit = done.future;
    try {
      await tryCatchAsync("init", () async {
        // Loading sentry.dll can take seconds (e.g. antivirus scan); do it off
        // the platform thread so the `native` open below only bumps a refcount.
        await _loadLibraryOnHelperIsolate(_dynamicLibraryPath);
        final cOptions = createOptions(options);
        _checkInitResult(
          await _initOnHelperIsolate(_dynamicLibraryPath, cOptions.address),
        );
        _scopeWorker = await _spawnScopeWorker(
          WorkerConfig(
            debugName: 'SentryNativeScopeWorker',
            debug: options.debug,
            diagnosticLevel: options.diagnosticLevel,
            automatedTestMode: options.automatedTestMode,
          ),
          dynamicLibraryDirectory,
        );
      });
    } finally {
      _pendingInit = null;
      done.complete();
    }
  }

  // Static, so the closure sent to the helper isolate captures only the
  // library path and the options address.
  static Future<int> _initOnHelperIsolate(
    String libraryPath,
    int optionsAddress,
  ) => Isolate.run(
    () => binding.SentryNative(
      DynamicLibrary.open(libraryPath),
    ).init(Pointer.fromAddress(optionsAddress)),
  );

  static Future<void> _loadLibraryOnHelperIsolate(String libraryPath) =>
      Isolate.run(() {
        DynamicLibrary.open(libraryPath);
      });

  void _checkInitResult(int code) {
    if (code != 0) {
      throw StateError(
        "Failed to initialize native SDK - init() exit code: $code",
      );
    }
    _nativeSdkAutoInitialized = true;
  }

  /// With the Crashpad backend on Windows, every scope change is a blocking
  /// IPC round-trip to crashpad_handler.exe, which waits for a free pipe
  /// instance without a timeout. Scope calls run on this worker so a busy
  /// handler (e.g. slow or antivirus-filtered disk) can't freeze the UI.
  Worker? _scopeWorker;

  @visibleForTesting
  bool get hasScopeWorker => _scopeWorker != null;

  // Static, so the worker entry captures only the library directory.
  static Future<Worker?> _spawnScopeWorker(
    WorkerConfig config,
    String libraryDirectory,
  ) async {
    try {
      final worker = await spawnWorker(config, (message) {
        dynamicLibraryDirectory = libraryDirectory;
        final (host, workerConfig) = message;
        runWorker(workerConfig, host, _ScopeCallHandler());
      });
      worker.closeOnOwnerExit();
      return worker;
    } catch (error, stackTrace) {
      internalLogger.error(
        'SentryNative: failed to start the scope worker, '
        'syncing the scope on the calling isolate',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// `sentry_init()` holds the native options lock, so scope calls made while
  /// it runs in the background would block the calling isolate until it ends.
  FutureOr<void> _scopeCall(String method, List<Object?> args) {
    final pending = _pendingInit;
    if (pending != null) {
      return pending.then((_) => _scopeCall(method, args));
    }
    final worker = _scopeWorker;
    tryCatchSync(method, () {
      if (worker != null) {
        worker.send((method, args));
      } else {
        _applyScopeCall(method, args);
      }
    });
  }

  static void _applyScopeCall(String method, List<Object?> args) {
    switch (method) {
      case 'remove_user':
        native.remove_user();
      case 'set_user':
        native.set_user((args[0] as Map<String, dynamic>).toNativeValue());
      case 'add_breadcrumb':
        native.add_breadcrumb(
          (args[0] as Map<String, dynamic>).toNativeValue(),
        );
      case 'set_context':
        _withNativeValue('context', args, native.set_context);
      case 'set_extra':
        _withNativeValue('extra', args, native.set_extra);
      case 'remove_context':
        _withNativeKey(args[0], native.remove_context);
      case 'remove_extra':
        _withNativeKey(args[0], native.remove_extra);
      case 'remove_tag':
        _withNativeKey(args[0], native.remove_tag);
      case 'set_tag':
        final c = FreeableFactory();
        native.set_tag(c.str(args[0] as String), c.str(args[1] as String));
        c.freeAll();
      default:
        throw ArgumentError.value(method, 'method', 'Unknown scope call');
    }
  }

  static void _withNativeKey(Object? key, void Function(Pointer<Char>) fn) {
    final cKey = (key as String).toNativeUtf8();
    fn(cKey.cast());
    malloc.free(cKey);
  }

  static void _withNativeValue(
    String kind,
    List<Object?> args,
    void Function(Pointer<Char>, binding.sentry_value_u) fn,
  ) {
    final key = args[0] as String;
    final cValue = dynamicToNativeValue(args[1]);
    if (cValue == null) {
      internalLogger.warning(
        'SentryNative: failed to set $kind $key - value couldn\'t be converted to native',
      );
      return;
    }
    _withNativeKey(key, (cKey) => fn(cKey, cValue));
  }

  @visibleForTesting
  Pointer<binding.sentry_options_s> createOptions(
    SentryFlutterOptions options,
  ) {
    final c = FreeableFactory();
    try {
      final cOptions = native.options_new();
      native.options_set_dsn(cOptions, c.str(options.dsn));
      if (options.sampleRate != null) {
        native.options_set_sample_rate(cOptions, options.sampleRate!);
      }
      native.options_set_debug(cOptions, options.debug ? 1 : 0);
      native.options_set_environment(cOptions, c.str(options.environment));
      native.options_set_release(cOptions, c.str(options.release));
      native.options_set_auto_session_tracking(
        cOptions,
        options.enableAutoSessionTracking ? 1 : 0,
      );
      native.options_set_dist(cOptions, c.str(options.dist));
      native.options_set_max_breadcrumbs(cOptions, options.maxBreadcrumbs);
      if (options.nativeDatabasePath != null) {
        native.options_set_database_path(
          cOptions,
          c.str(options.nativeDatabasePath),
        );
      }
      if (options.proxy != null) {
        // sentry-native expects a single string and it doesn't support different types or authentication
        internalLogger.warning(
          'SentryNative: setting a proxy is currently not supported',
        );
      }

      if (crashpadPath != null) {
        native.options_set_handler_path(cOptions, c.str(crashpadPath));
      } else {
        internalLogger.debug(
          'SentryNative: no Crashpad handler path override. '
          'Breakpad does not need a handler; if Crashpad is selected, '
          'the native SDK will use its default handler location.',
        );
      }

      return cOptions;
    } finally {
      c.freeAll();
    }
  }

  @override
  FutureOr<void> close() {
    final pending = _pendingInit;
    if (pending != null) {
      return pending.then((_) => close());
    }
    _scopeWorker?.close();
    _scopeWorker = null;
    if (!_nativeSdkAutoInitialized) {
      return null;
    }
    tryCatchSync('close', native.close);
  }

  @override
  FutureOr<NativeAppStart?> fetchNativeAppStart() => null;

  @override
  bool get supportsCaptureEnvelope => false;

  @override
  FutureOr<void> captureEnvelope(Uint8List envelopeData) {
    throw UnsupportedError('$SentryNative.captureEnvelope() is not supported');
  }

  @override
  FutureOr<void> updateSessionForDroppedEventNonTerminating(bool unhandled) {
    throw UnsupportedError(
      '$SentryNative.updateSessionForDroppedEventNonTerminating() is not supported',
    );
  }

  @override
  FutureOr<void> captureStructuredEnvelope(SentryEnvelope envelope) {
    throw UnsupportedError("Not supported on this platform");
  }

  @override
  FutureOr<void> setUser(SentryUser? user) => user == null
      ? _scopeCall('remove_user', const [])
      : _scopeCall('set_user', [user.toJson()]);

  @override
  FutureOr<void> addBreadcrumb(Breadcrumb breadcrumb) =>
      _scopeCall('add_breadcrumb', [breadcrumb.toJson()]);

  @override
  FutureOr<void> clearBreadcrumbs() {
    _logNotSupported('clearing breadcrumbs');
  }

  @override
  bool get supportsLoadContexts => false;

  @override
  FutureOr<Map<String, dynamic>?> loadContexts() {
    _logNotSupported('loading contexts');
    return null;
  }

  @override
  FutureOr<void> setContexts(String key, dynamic value) =>
      _scopeCall('set_context', [key, value]);

  @override
  FutureOr<void> removeContexts(String key) =>
      _scopeCall('remove_context', [key]);

  @override
  FutureOr<void> setExtra(String key, dynamic value) =>
      _scopeCall('set_extra', [key, value]);

  @override
  FutureOr<void> removeExtra(String key) => _scopeCall('remove_extra', [key]);

  @override
  FutureOr<void> setTag(String key, String value) =>
      _scopeCall('set_tag', [key, value]);

  @override
  FutureOr<void> removeTag(String key) => _scopeCall('remove_tag', [key]);

  @override
  FutureOr<int?> displayRefreshRate() {
    _logNotSupported('collecting display refresh rate');
    return null;
  }

  @override
  FutureOr<List<DebugImage>?> loadDebugImages(SentryStackTrace stackTrace) =>
      tryCatchAsync('get_module_list', () async {
        final cImages = native.get_modules_list();
        try {
          if (native.value_get_type(cImages) !=
              binding.sentry_value_type_t.SENTRY_VALUE_TYPE_LIST) {
            return null;
          }

          final images = List<DebugImage>.generate(
            native.value_get_length(cImages),
            (index) {
              final cImage = native.value_get_by_index(cImages, index);
              return DebugImage(
                type: cImage.get('type').castPrimitive() ?? '',
                imageAddr: cImage.get('image_addr').castPrimitive(),
                imageSize: cImage.get('image_size').castPrimitive(),
                codeFile: cImage.get('code_file').castPrimitive(),
                debugId: cImage.get('debug_id').castPrimitive(),
                debugFile: cImage.get('debug_file').castPrimitive(),
                codeId: cImage.get('code_id').castPrimitive(),
              );
            },
          );
          return images;
        } finally {
          native.value_decref(cImages);
        }
      });

  @override
  FutureOr<void> pauseAppHangTracking() {}

  @override
  FutureOr<void> resumeAppHangTracking() {}

  @override
  FutureOr<void> nativeCrash() {
    Pointer.fromAddress(1).cast<Utf8>().toDartString();
  }

  @override
  bool get supportsReplay => false;

  @override
  SentryId? get replayId => null;

  @override
  String? get proguardUuid => null;

  @override
  FutureOr<void> setReplayConfig(ReplayConfig config) {
    _logNotSupported('replay config');
  }

  @override
  FutureOr<SentryId> captureReplay() {
    _logNotSupported('capturing replay');
    return SentryId.empty();
  }

  @override
  FutureOr<void> startReplay() {
    _logNotSupported('starting replay');
  }

  @override
  FutureOr<void> startReplayBuffering() {
    _logNotSupported('starting replay buffering');
  }

  @override
  FutureOr<void> pauseReplay() {
    _logNotSupported('pausing replay');
  }

  @override
  FutureOr<void> resumeReplay() {
    _logNotSupported('resuming replay');
  }

  @override
  FutureOr<void> stopReplay() {
    _logNotSupported('stopping replay');
  }

  @override
  FutureOr<void> flushReplay() {
    _logNotSupported('flushing replay');
  }

  @override
  FutureOr<void> startSession({bool ignoreDuration = false}) {
    _logNotSupported('starting session');
  }

  @override
  FutureOr<void> captureSession() {
    _logNotSupported('capturing session');
  }

  @override
  FutureOr<Map<dynamic, dynamic>?> getSession() {
    _logNotSupported('getting session');
    return null;
  }

  @override
  FutureOr<void> updateSession({int? errors, String? status}) {
    _logNotSupported('updating session');
  }

  @override
  bool get supportsTraceSync => false;

  @override
  FutureOr<void> setTrace(SentryId traceId, SpanId spanId) {
    _logNotSupported('setting trace');
  }

  @override
  FutureOr<void> registerTraceId(SentryId traceId) {
    // No-op. Replay trace ID registration is currently Android-only.
  }

  @override
  FutureOr<void> registerSegmentName(String segmentName) {
    // No-op. Replay segment name registration is currently Android-only.
  }
}

class _ScopeCallHandler extends WorkerHandler {
  @override
  void onMessage(Object? message) {
    final (method, args) = message as (String, List<Object?>);
    SentryNative._applyScopeCall(method, args);
  }
}

extension SentryValueExtension on binding.sentry_value_u {
  void setNativeValue(String key, binding.sentry_value_u? value) {
    final cKey = key.toNativeUtf8();
    if (value == null) {
      SentryNative.native.value_remove_by_key(this, cKey.cast());
    } else {
      SentryNative.native.value_set_by_key(this, cKey.cast(), value);
    }
    malloc.free(cKey);
  }

  binding.sentry_value_u get(String key) {
    final cKey = key.toNativeUtf8();
    try {
      return SentryNative.native.value_get_by_key(this, cKey.cast());
    } finally {
      malloc.free(cKey);
    }
  }

  T? castPrimitive<T>() {
    if (SentryNative.native.value_is_null(this) == 1) {
      return null;
    }
    final type = SentryNative.native.value_get_type(this);
    switch (type) {
      case binding.sentry_value_type_t.SENTRY_VALUE_TYPE_NULL:
        return null;
      case binding.sentry_value_type_t.SENTRY_VALUE_TYPE_BOOL:
        return (SentryNative.native.value_is_true(this) == 1) as T;
      case binding.sentry_value_type_t.SENTRY_VALUE_TYPE_INT32:
        return SentryNative.native.value_as_int32(this) as T;
      case binding.sentry_value_type_t.SENTRY_VALUE_TYPE_INT64:
        return SentryNative.native.value_as_int64(this) as T;
      case binding.sentry_value_type_t.SENTRY_VALUE_TYPE_UINT64:
        // Dart's int is signed 64-bit, so a uint64 above 2^63-1 wraps to a
        // negative number. Drop it rather than propagate a corrupt value.
        final value = SentryNative.native.value_as_uint64(this);
        if (value < 0) {
          internalLogger.warning(
            'SentryNative: uint64 value exceeds signed int64 range and '
            'cannot be represented as a Dart int',
          );
          return null;
        }
        return value as T;
      case binding.sentry_value_type_t.SENTRY_VALUE_TYPE_DOUBLE:
        return SentryNative.native.value_as_double(this) as T;
      case binding.sentry_value_type_t.SENTRY_VALUE_TYPE_STRING:
        return SentryNative.native
                .value_as_string(this)
                .cast<Utf8>()
                .toDartString()
            as T;
      default:
        internalLogger.warning(
          'SentryNative: cannot read native value type: $type',
        );
        return null;
    }
  }
}

binding.sentry_value_u? dynamicToNativeValue(dynamic value) {
  if (value is String) {
    return value.toNativeValue();
  } else if (value is int) {
    return value.toNativeValue();
  } else if (value is double) {
    return value.toNativeValue();
  } else if (value is bool) {
    return value.toNativeValue();
  } else if (value is Map<String, dynamic>) {
    return value.toNativeValue();
  } else if (value is List) {
    return value.toNativeValue();
  } else if (value == null) {
    return SentryNative.native.value_new_null();
  } else {
    internalLogger.warning(
      'SentryNative: unsupported data for conversion: ${value.runtimeType} ($value)',
    );
    return null;
  }
}

extension on String {
  binding.sentry_value_u toNativeValue() {
    final cValue = toNativeUtf8();
    final result = SentryNative.native.value_new_string(cValue.cast());
    malloc.free(cValue);
    return result;
  }
}

const _int32Min = -2147483648; // -(2^31)
const _int32Max = 2147483647; // 2^31 - 1

extension on int {
  binding.sentry_value_u toNativeValue() {
    if (this >= _int32Min && this <= _int32Max) {
      return SentryNative.native.value_new_int32(this);
    } else {
      return SentryNative.native.value_new_int64(this);
    }
  }
}

extension on double {
  binding.sentry_value_u toNativeValue() =>
      SentryNative.native.value_new_double(this);
}

extension on bool {
  binding.sentry_value_u toNativeValue() =>
      SentryNative.native.value_new_bool(this ? 1 : 0);
}

extension on Map<String, dynamic> {
  binding.sentry_value_u toNativeValue() {
    final cObject = SentryNative.native.value_new_object();
    for (final entry in entries) {
      final cValue = dynamicToNativeValue(entry.value);
      cObject.setNativeValue(entry.key, cValue);
    }
    return cObject;
  }
}

extension on List<dynamic> {
  binding.sentry_value_u toNativeValue() {
    final cObject = SentryNative.native.value_new_list();
    for (final value in this) {
      final cValue = dynamicToNativeValue(value);
      if (cValue != null) {
        SentryNative.native.value_append(cObject, cValue);
      }
    }
    return cObject;
  }
}

String? _getDefaultCrashpadPath() {
  if (Platform.isLinux) {
    final lastSeparator = Platform.resolvedExecutable.lastIndexOf(
      Platform.pathSeparator,
    );
    if (lastSeparator >= 0) {
      final appDir = Platform.resolvedExecutable.substring(0, lastSeparator);
      final candidates = [
        '$appDir${Platform.pathSeparator}crashpad_handler',
        '$appDir${Platform.pathSeparator}bin${Platform.pathSeparator}crashpad_handler',
        '$appDir${Platform.pathSeparator}lib${Platform.pathSeparator}crashpad_handler',
      ];
      return candidates.firstWhereOrNull((path) => File(path).existsSync());
    }
  }
  return null;
}
