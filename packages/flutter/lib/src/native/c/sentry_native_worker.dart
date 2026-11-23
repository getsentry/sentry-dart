// ignore_for_file: invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../isolate/isolate_worker.dart';
import '../../utils/internal_logger.dart';
import '../sentry_native_invoker.dart';
import '../utils/data_normalizer.dart';
import 'binding.dart' as binding;
import 'sentry_native.dart';
import 'utils.dart';
import 'windows_library_loader.dart';

/// Runs sentry-native on a worker isolate on Windows.
///
/// The root isolate runs on the platform thread there, so loading sentry.dll
/// (e.g. an antivirus scan), a blocking `sentry_init()` (e.g. waiting for the
/// Crashpad handler) and, with Crashpad, every scope call (a blocking IPC
/// round-trip without a timeout) would freeze the UI.
@internal
class SentryNativeWorker with SentryNativeSafeInvoker {
  SentryNativeWorker(this.options, this._createOptions) {
    // Init never runs; the app's own native SDK takes the calls.
    if (!options.autoInitializeNativeSdk) _ready.complete(null);
  }

  @override
  final SentryFlutterOptions options;
  final Pointer<binding.sentry_options_s> Function() _createOptions;

  /// Completes once init decided where native calls run: on this worker, or
  /// on the calling isolate when it is null.
  final _ready = Completer<Worker?>();
  Future<Worker?>? _started;
  bool _initializedOnCallingIsolate = false;

  /// Init failed, so native calls are dropped rather than run on the calling
  /// isolate.
  bool _initFailed = false;
  bool _closed = false;
  int _pendingRequests = 0;

  /// The latest close, which the next init waits for. Static because native
  /// SDK state is per process and a re-init creates a new binding.
  static Future<void> _previousClose = Future.value();

  @visibleForTesting
  static void resetPreviousClose() => _previousClose = Future.value();

  @visibleForTesting
  static SpawnWorkerFn spawnWorkerFn = spawnWorker;

  @visibleForTesting
  static Duration closeTimeout = const Duration(seconds: 5);

  /// Calls beyond this are dropped while the worker is stuck, e.g. on a busy
  /// Crashpad handler.
  @visibleForTesting
  static int maxPendingRequests = 1000;

  /// Completes once init has finished, with its error if it failed.
  @visibleForTesting
  Future<void> get initialized => _started ?? _ready.future;

  /// The worker native calls run on; null when they run on the calling
  /// isolate.
  @visibleForTesting
  Future<Worker?> get target => _ready.future;

  @visibleForTesting
  void useWorker(Worker worker) {
    _started = Future.value(worker);
    _ready.complete(worker);
  }

  /// Returns without waiting, so the first frame doesn't wait for
  /// `sentry_init()`. Native crashes before it finishes are not captured.
  void start() {
    final started = _started = _start();
    started.ignore();
    _ready.complete(
      started.then<Worker?>(
        (worker) => worker,
        onError: (Object error, StackTrace stackTrace) {
          _initFailed = true;
          internalLogger.error(
            'Native call `init` failed',
            error: error,
            stackTrace: stackTrace,
          );
          return null;
        },
      ),
    );
  }

  /// With crash handling off, scope calls still reach native, as on Linux.
  void startWithoutInit() => _ready.complete(null);

  Future<Worker?> _start() async {
    // sentry_init() must not overlap a sentry_close() still running.
    await _previousClose;
    final worker = await _spawn();
    if (worker == null) {
      checkNativeInitResult(SentryNative.native.init(_createOptions()));
      _initializedOnCallingIsolate = true;
      return null;
    }
    try {
      final guarantee = await worker.request(const _LoadRequest());
      _setThreadStackGuarantee(guarantee as int);
      // Once the worker loaded the library, `native` here only bumps a
      // refcount.
      final cOptions = _createOptions();
      final code = await worker.request(_InitRequest(cOptions.address));
      checkNativeInitResult(code as int);
      return worker;
    } catch (_) {
      worker.close();
      rethrow;
    }
  }

  Future<Worker?> _spawn() async {
    final libraryDirectory = SentryNative.dynamicLibraryDirectory;
    try {
      final worker = await spawnWorkerFn(
        WorkerConfig(
          debugName: 'SentryNativeWorker',
          debug: options.debug,
          diagnosticLevel: options.diagnosticLevel,
          automatedTestMode: options.automatedTestMode,
        ),
        (message) {
          SentryNative.dynamicLibraryDirectory = libraryDirectory;
          final (host, config) = message;
          runWorker(config, host, _NativeWorkerHandler());
        },
      );
      worker.closeOnOwnerExit();
      return worker;
    } catch (error, stackTrace) {
      internalLogger.error(
        'SentryNative: failed to start the native worker, '
        'using the calling isolate',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  FutureOr<void> setUser(SentryUser? user) => _send(
    user == null ? 'remove_user' : 'set_user',
    () => _SetUserRequest(
      user == null ? null : normalize(user.toJson()) as Map<String, dynamic>,
    ),
  );

  FutureOr<void> addBreadcrumb(Breadcrumb breadcrumb) => _send(
    'add_breadcrumb',
    () => _AddBreadcrumbRequest(
      normalize(breadcrumb.toJson()) as Map<String, dynamic>,
    ),
  );

  FutureOr<void> setContexts(String key, dynamic value) =>
      _send('set_context', () => _SetContextsRequest(key, normalize(value)));

  FutureOr<void> removeContexts(String key) =>
      _send('remove_context', () => _RemoveContextsRequest(key));

  FutureOr<void> setExtra(String key, dynamic value) =>
      _send('set_extra', () => _SetExtraRequest(key, normalize(value)));

  FutureOr<void> removeExtra(String key) =>
      _send('remove_extra', () => _RemoveExtraRequest(key));

  FutureOr<void> setTag(String key, String value) =>
      _send('set_tag', () => _SetTagRequest(key, value));

  FutureOr<void> removeTag(String key) =>
      _send('remove_tag', () => _RemoveTagRequest(key));

  /// Completes once the native call has returned. Calls run in call order:
  /// `then` callbacks on [_ready] run in the order they were added, and the
  /// worker answers one request at a time.
  FutureOr<void> _send(String name, _ScopeRequest Function() build) {
    if (_closed) return null;
    if (_pendingRequests >= maxPendingRequests) {
      internalLogger.warning(
        'SentryNative: $name dropped, $maxPendingRequests calls are already '
        'waiting for the native SDK',
      );
      return null;
    }
    final request = tryCatchSync(name, build);
    if (request == null) return null;
    _pendingRequests++;
    final result = tryCatchAsync<void>(
      name,
      () => _ready.future
          .then((worker) async {
            if (worker == null) {
              if (!_initFailed) request.apply();
            } else {
              await worker.request(request);
            }
          })
          .whenComplete(() => _pendingRequests--),
    );
    // Nothing guarantees init will start, so a caller can't wait for it.
    if (_started == null && !_ready.isCompleted) {
      result.ignore();
      return null;
    }
    return result;
  }

  /// Waits for init, which loads the library on the worker. Returns null
  /// before init starts, rather than holding up the event.
  Future<List<DebugImage>?> loadDebugImages() {
    if (_closed || (_started == null && !_ready.isCompleted)) {
      return Future.value(null);
    }
    return tryCatchAsync(
      'get_module_list',
      () => _ready.future
          .then((worker) async {
            if (worker == null) {
              return _initFailed ? null : readNativeDebugImages();
            }
            final images = await worker.request(
              const _LoadDebugImagesRequest(),
            );
            return images as List<DebugImage>?;
          })
          .timeout(closeTimeout, onTimeout: () => null),
    );
  }

  /// Runs after every call made before it, then shuts the worker down.
  Future<void> close() {
    if (_closed) return Future.value();
    _closed = true;
    // Never initialized, so there is nothing to close.
    if (_started == null && !_ready.isCompleted) return Future.value();
    final Future<void> closed = _ready.future.then((worker) async {
      if (worker != null) {
        final request = worker.request(const _CloseRequest());
        worker.close();
        await request;
      } else if (_initializedOnCallingIsolate) {
        SentryNative.native.close();
      }
    });
    _previousClose = closed.then((_) {}, onError: (Object _) {});
    return tryCatchAsync<void>(
      'close',
      () => closed.timeout(
        closeTimeout,
        onTimeout: () => internalLogger.warning(
          'SentryNative: close did not finish within $closeTimeout, '
          'it continues in the background',
        ),
      ),
    );
  }

  /// sentry.dll's DllMain gives a stack guarantee, which lets the crash handler
  /// report a stack overflow, only to the thread that loads it and to threads
  /// started later. The worker loaded it, so the platform thread copies the
  /// worker's guarantee.
  static void _setThreadStackGuarantee(int bytes) {
    if (bytes == 0 || threadStackGuarantee() != 0) return;
    final cBytes = malloc<Uint32>()..value = bytes;
    try {
      _kernel32SetThreadStackGuarantee(cBytes);
    } finally {
      malloc.free(cBytes);
    }
  }

  /// The calling thread's stack guarantee in bytes; 0 if none is set.
  @visibleForTesting
  static int threadStackGuarantee() {
    final cBytes = malloc<Uint32>()..value = 0;
    try {
      return _kernel32SetThreadStackGuarantee(cBytes) == 0 ? 0 : cBytes.value;
    } finally {
      malloc.free(cBytes);
    }
  }

  // Passing 0 only reads the current guarantee.
  static final _kernel32SetThreadStackGuarantee =
      DynamicLibrary.open('kernel32.dll').lookupFunction<
        Int32 Function(Pointer<Uint32>),
        int Function(Pointer<Uint32>)
      >('SetThreadStackGuarantee');
}

class _NativeWorkerHandler extends WorkerHandler {
  @override
  void onMessage(Object? message) {}

  @override
  Object? onRequest(Object? payload) {
    switch (payload) {
      case _LoadRequest():
        // Unlike DynamicLibrary.open, this lets the other isolates collect
        // garbage while the DLL loads (e.g. during an antivirus scan).
        WindowsLibraryLoader(
          DynamicLibrary.open('kernel32.dll'),
        ).load('${SentryNative.dynamicLibraryDirectory}sentry.dll');
        // Its DllMain just set this thread's stack guarantee.
        return SentryNativeWorker.threadStackGuarantee();
      case _InitRequest(:final optionsAddress):
        return SentryNative.native.init(Pointer.fromAddress(optionsAddress));
      case _LoadDebugImagesRequest():
        return readNativeDebugImages();
      case _CloseRequest():
        SentryNative.native.close();
        return null;
      case _ScopeRequest():
        payload.apply();
        return null;
      default:
        throw ArgumentError.value(payload, 'payload', 'Unknown request');
    }
  }
}

final class _LoadRequest {
  const _LoadRequest();
}

final class _InitRequest {
  const _InitRequest(this.optionsAddress);

  final int optionsAddress;
}

final class _LoadDebugImagesRequest {
  const _LoadDebugImagesRequest();
}

final class _CloseRequest {
  const _CloseRequest();
}

sealed class _ScopeRequest {
  const _ScopeRequest();

  void apply();
}

final class _SetUserRequest extends _ScopeRequest {
  const _SetUserRequest(this.user);

  final Map<String, dynamic>? user;

  @override
  void apply() {
    final user = this.user;
    if (user == null) {
      SentryNative.native.remove_user();
    } else {
      SentryNative.native.set_user(dynamicToNativeValue(user)!);
    }
  }
}

final class _AddBreadcrumbRequest extends _ScopeRequest {
  const _AddBreadcrumbRequest(this.breadcrumb);

  final Map<String, dynamic> breadcrumb;

  @override
  void apply() =>
      SentryNative.native.add_breadcrumb(dynamicToNativeValue(breadcrumb)!);
}

final class _SetContextsRequest extends _ScopeRequest {
  const _SetContextsRequest(this.key, this.value);

  final String key;
  final Object? value;

  @override
  void apply() =>
      _withKeyAndValue('context', key, value, SentryNative.native.set_context);
}

final class _RemoveContextsRequest extends _ScopeRequest {
  const _RemoveContextsRequest(this.key);

  final String key;

  @override
  void apply() => _withKey(key, SentryNative.native.remove_context);
}

final class _SetExtraRequest extends _ScopeRequest {
  const _SetExtraRequest(this.key, this.value);

  final String key;
  final Object? value;

  @override
  void apply() =>
      _withKeyAndValue('extra', key, value, SentryNative.native.set_extra);
}

final class _RemoveExtraRequest extends _ScopeRequest {
  const _RemoveExtraRequest(this.key);

  final String key;

  @override
  void apply() => _withKey(key, SentryNative.native.remove_extra);
}

final class _SetTagRequest extends _ScopeRequest {
  const _SetTagRequest(this.key, this.value);

  final String key;
  final String value;

  @override
  void apply() {
    final c = FreeableFactory();
    try {
      SentryNative.native.set_tag(c.str(key), c.str(value));
    } finally {
      c.freeAll();
    }
  }
}

final class _RemoveTagRequest extends _ScopeRequest {
  const _RemoveTagRequest(this.key);

  final String key;

  @override
  void apply() => _withKey(key, SentryNative.native.remove_tag);
}

void _withKey(String key, void Function(Pointer<Char>) fn) {
  final cKey = key.toNativeUtf8();
  try {
    fn(cKey.cast());
  } finally {
    malloc.free(cKey);
  }
}

void _withKeyAndValue(
  String kind,
  String key,
  Object? value,
  void Function(Pointer<Char>, binding.sentry_value_u) fn,
) {
  final cValue = dynamicToNativeValue(value);
  if (cValue == null) {
    internalLogger.warning(
      'SentryNative: failed to set $kind $key - value couldn\'t be converted '
      'to native',
    );
    return;
  }
  _withKey(key, (cKey) => fn(cKey, cValue));
}
