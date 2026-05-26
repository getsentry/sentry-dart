import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:jni/jni.dart';
import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../isolate/isolate_worker.dart';
import '../utils/data_normalizer.dart';
import '../utils/utf8_json.dart';
import '../../utils/internal_logger.dart';
import 'binding.dart' as native;

/// Runs Android JNI work on a background isolate when available.
class AndroidCoreWorker {
  final WorkerConfig _config;
  final SpawnWorkerFn _spawn;

  bool _isClosed = false;
  Future<void>? _startFuture;
  Worker? _worker;

  AndroidCoreWorker(SentryOptions options, {SpawnWorkerFn? spawn})
      : _config = WorkerConfig(
          debugName: 'SentryAndroidCoreWorker',
          debug: options.debug,
          diagnosticLevel: options.diagnosticLevel,
          // ignore: invalid_use_of_internal_member
          automatedTestMode: options.automatedTestMode,
        ),
        _spawn = spawn ?? spawnWorker;

  @internal
  static AndroidCoreWorker Function(SentryFlutterOptions) factory =
      AndroidCoreWorker.new;

  FutureOr<void> start() {
    if (_isClosed) return null;
    if (_worker != null) return null;
    if (_startFuture != null) return _startFuture;
    _startFuture = _start();
    return _startFuture;
  }

  Future<void> _start() async {
    try {
      final worker = await _spawn(_config, _entryPoint);
      // Guard against close() being called during spawn.
      if (_isClosed) {
        worker.close();
        return;
      }
      _worker = worker;
    } catch (exception, stackTrace) {
      internalLogger.error(
        'Failed to start Android core worker',
        error: exception,
        stackTrace: stackTrace,
      );
    } finally {
      _startFuture = null;
    }
  }

  FutureOr<void> close() async {
    _isClosed = true;
    await _startFuture;
    _worker?.close();
    _worker = null;
  }

  void captureEnvelope(
    Uint8List envelopeData,
    bool containsUnhandledException,
  ) {
    if (_isClosed) return;

    final client = _worker;
    if (client == null) {
      internalLogger.info(
        'captureEnvelope called before core worker started: sending envelope in main isolate instead',
      );
      _captureEnvelope(
        envelopeData,
        containsUnhandledException,
        automatedTestMode: _config.automatedTestMode,
      );
      return;
    }

    _captureEnvelopeFromWorker(
      client,
      envelopeData,
      containsUnhandledException,
    );
  }

  void _captureEnvelopeFromWorker(
    Worker client,
    Uint8List envelopeData,
    bool containsUnhandledException,
  ) {
    client.send(
      _CaptureEnvelopeRequest(
        TransferableTypedData.fromList([envelopeData]),
        containsUnhandledException,
      ),
    );
  }

  FutureOr<List<DebugImage>?> loadDebugImages(SentryStackTrace stackTrace) {
    if (_isClosed) return null;

    final instructionAddresses = stackTrace.frames
        .map((f) => f.instructionAddr)
        .nonNulls
        .toList(growable: false);

    final client = _worker;
    if (client == null) {
      return _loadDebugImages(
        instructionAddresses,
        automatedTestMode: _config.automatedTestMode,
      );
    }

    return _loadDebugImagesFromWorker(client, instructionAddresses);
  }

  Future<List<DebugImage>?> _loadDebugImagesFromWorker(
    Worker client,
    List<String> instructionAddresses,
  ) async {
    try {
      final response = await client.request(
        _LoadDebugImagesRequest(instructionAddresses),
      );
      final maps = (response as List?)
          ?.whereType<Map<dynamic, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
      return maps?.map(DebugImage.fromJson).toList(growable: false);
    } catch (exception, stackTrace) {
      internalLogger.error(
        'Android core worker failed to load debug images',
        error: exception,
        stackTrace: stackTrace,
      );
      if (_config.automatedTestMode) {
        rethrow;
      }
      return null;
    }
  }

  FutureOr<Map<String, dynamic>?> loadContexts() {
    if (_isClosed) return null;

    final client = _worker;
    if (client == null) {
      return _loadContexts(automatedTestMode: _config.automatedTestMode);
    }

    return _loadContextsFromWorker(client);
  }

  Future<Map<String, dynamic>?> _loadContextsFromWorker(Worker client) async {
    try {
      final response = await client.request(const _LoadContextsRequest());
      return response == null
          ? null
          : Map<String, dynamic>.from(response as Map);
    } catch (exception, stackTrace) {
      internalLogger.error(
        'Android core worker failed to load contexts',
        error: exception,
        stackTrace: stackTrace,
      );
      if (_config.automatedTestMode) {
        rethrow;
      }
      return null;
    }
  }

  FutureOr<void> addBreadcrumb(Breadcrumb breadcrumb) {
    if (_isClosed) return null;

    final client = _worker;
    if (client == null) {
      _addBreadcrumb(
        breadcrumb.toJson(),
        automatedTestMode: _config.automatedTestMode,
      );
      return null;
    }

    return _addBreadcrumbFromWorker(client, breadcrumb);
  }

  Future<void> _addBreadcrumbFromWorker(
    Worker client,
    Breadcrumb breadcrumb,
  ) async {
    try {
      await client.request(
        _AddBreadcrumbRequest(
          normalize(breadcrumb.toJson()) as Map<String, dynamic>,
        ),
      );
    } catch (exception, stackTrace) {
      internalLogger.error(
        'Android core worker failed to add breadcrumb',
        error: exception,
        stackTrace: stackTrace,
      );
      if (_config.automatedTestMode) {
        rethrow;
      }
    }
  }

  FutureOr<void> clearBreadcrumbs() {
    if (_isClosed) return null;

    final client = _worker;
    if (client == null) {
      _clearBreadcrumbs(automatedTestMode: _config.automatedTestMode);
      return null;
    }

    return _clearBreadcrumbsFromWorker(client);
  }

  Future<void> _clearBreadcrumbsFromWorker(Worker client) async {
    try {
      await client.request(const _ClearBreadcrumbsRequest());
    } catch (exception, stackTrace) {
      internalLogger.error(
        'Android core worker failed to clear breadcrumbs',
        error: exception,
        stackTrace: stackTrace,
      );
      if (_config.automatedTestMode) {
        rethrow;
      }
    }
  }

  FutureOr<void> setUser(SentryUser? user) {
    if (_isClosed) return null;

    final client = _worker;
    if (client == null) {
      _setUser(user?.toJson(), automatedTestMode: _config.automatedTestMode);
      return null;
    }

    return _setUserFromWorker(client, user);
  }

  Future<void> _setUserFromWorker(Worker client, SentryUser? user) async {
    try {
      await client.request(
        _SetUserRequest(
          user == null
              ? null
              : normalize(user.toJson()) as Map<String, dynamic>,
        ),
      );
    } catch (exception, stackTrace) {
      internalLogger.error(
        'Android core worker failed to set user',
        error: exception,
        stackTrace: stackTrace,
      );
      if (_config.automatedTestMode) {
        rethrow;
      }
    }
  }

  FutureOr<void> setContexts(String key, dynamic value) {
    if (_isClosed) return null;

    final normalizedValue = normalize(value);
    final client = _worker;
    if (client == null) {
      _setContexts(
        key,
        normalizedValue,
        automatedTestMode: _config.automatedTestMode,
      );
      return null;
    }

    return _setContextsFromWorker(client, key, normalizedValue);
  }

  Future<void> _setContextsFromWorker(
    Worker client,
    String key,
    Object? value,
  ) async {
    try {
      await client.request(_SetContextsRequest(key, value));
    } catch (exception, stackTrace) {
      internalLogger.error(
        'Android core worker failed to set context',
        error: exception,
        stackTrace: stackTrace,
      );
      if (_config.automatedTestMode) {
        rethrow;
      }
    }
  }

  FutureOr<void> removeContexts(String key) {
    if (_isClosed) return null;

    final client = _worker;
    if (client == null) {
      _removeContexts(key, automatedTestMode: _config.automatedTestMode);
      return null;
    }

    return _removeContextsFromWorker(client, key);
  }

  Future<void> _removeContextsFromWorker(Worker client, String key) async {
    try {
      await client.request(_RemoveContextsRequest(key));
    } catch (exception, stackTrace) {
      internalLogger.error(
        'Android core worker failed to remove context',
        error: exception,
        stackTrace: stackTrace,
      );
      if (_config.automatedTestMode) {
        rethrow;
      }
    }
  }

  static void _entryPoint((SendPort, WorkerConfig) init) {
    final (host, config) = init;
    runWorker(config, host, _AndroidCoreWorkerHandler(config));
  }
}

class _AndroidCoreWorkerHandler extends WorkerHandler {
  final WorkerConfig _config;
  Future<void> _queue = Future.value();

  _AndroidCoreWorkerHandler(this._config);

  @override
  FutureOr<void> onMessage(Object? msg) => _enqueue(() {
        switch (msg) {
          case _CaptureEnvelopeRequest request:
            final data = request.envelopeData.materialize().asUint8List();
            _captureEnvelope(
              data,
              request.containsUnhandledException,
              automatedTestMode: _config.automatedTestMode,
            );
          case _AddBreadcrumbRequest request:
            _addBreadcrumb(
              request.breadcrumb,
              automatedTestMode: _config.automatedTestMode,
            );
          case _ClearBreadcrumbsRequest _:
            _clearBreadcrumbs(automatedTestMode: _config.automatedTestMode);
          case _SetUserRequest request:
            _setUser(request.user,
                automatedTestMode: _config.automatedTestMode);
          case _SetContextsRequest request:
            _setContexts(
              request.key,
              request.value,
              automatedTestMode: _config.automatedTestMode,
            );
          case _RemoveContextsRequest request:
            _removeContexts(
              request.key,
              automatedTestMode: _config.automatedTestMode,
            );
          default:
            _unexpectedMessage(msg);
        }
      });

  @override
  FutureOr<Object?> onRequest(Object? payload) => _enqueue<Object?>(() {
        switch (payload) {
          case _LoadDebugImagesRequest request:
            return _loadDebugImageMaps(
              request.instructionAddresses,
              automatedTestMode: _config.automatedTestMode,
            );
          case _LoadContextsRequest _:
            return _loadContexts(automatedTestMode: _config.automatedTestMode);
          case _AddBreadcrumbRequest request:
            _addBreadcrumb(
              request.breadcrumb,
              automatedTestMode: _config.automatedTestMode,
            );
            return null;
          case _ClearBreadcrumbsRequest _:
            _clearBreadcrumbs(automatedTestMode: _config.automatedTestMode);
            return null;
          case _SetUserRequest request:
            _setUser(request.user,
                automatedTestMode: _config.automatedTestMode);
            return null;
          case _SetContextsRequest request:
            _setContexts(
              request.key,
              request.value,
              automatedTestMode: _config.automatedTestMode,
            );
            return null;
          case _RemoveContextsRequest request:
            _removeContexts(
              request.key,
              automatedTestMode: _config.automatedTestMode,
            );
            return null;
          default:
            return _unexpectedPayload(payload);
        }
      });

  /// Serializes worker actions so JNI calls run in request order.
  Future<T> _enqueue<T>(FutureOr<T> Function() action) {
    final next = _queue.then((_) => action());
    _queue = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  Object? _unexpectedPayload(Object? payload) {
    internalLogger.warning(
      '${_config.debugName}: unexpected payload type: $payload',
    );
    return null;
  }

  void _unexpectedMessage(Object? msg) {
    internalLogger.warning(
      '${_config.debugName}: unexpected message type: $msg',
    );
  }
}

class _CaptureEnvelopeRequest {
  final TransferableTypedData envelopeData;
  final bool containsUnhandledException;

  const _CaptureEnvelopeRequest(
    this.envelopeData,
    this.containsUnhandledException,
  );
}

class _LoadDebugImagesRequest {
  final List<String> instructionAddresses;

  const _LoadDebugImagesRequest(this.instructionAddresses);
}

class _LoadContextsRequest {
  const _LoadContextsRequest();
}

class _AddBreadcrumbRequest {
  final Map<String, dynamic> breadcrumb;

  const _AddBreadcrumbRequest(this.breadcrumb);
}

class _ClearBreadcrumbsRequest {
  const _ClearBreadcrumbsRequest();
}

class _SetUserRequest {
  final Map<String, dynamic>? user;

  const _SetUserRequest(this.user);
}

class _SetContextsRequest {
  final String key;
  final Object? value;

  const _SetContextsRequest(this.key, this.value);
}

class _RemoveContextsRequest {
  final String key;

  const _RemoveContextsRequest(this.key);
}

void _captureEnvelope(
  Uint8List envelopeData,
  bool containsUnhandledException, {
  bool automatedTestMode = false,
}) {
  JObject? id;
  JByteArray? byteArray;
  try {
    byteArray = JByteArray.from(envelopeData);
    id = native.InternalSentrySdk.captureEnvelope(
      byteArray,
      containsUnhandledException,
    );

    if (id == null) {
      internalLogger.error(
        'Native Android SDK returned null when capturing envelope',
      );
    }
  } catch (exception, stackTrace) {
    internalLogger.error(
      'Failed to capture envelope',
      error: exception,
      stackTrace: stackTrace,
    );
    if (automatedTestMode) {
      rethrow;
    }
  } finally {
    byteArray?.release();
    id?.release();
  }
}

List<DebugImage>? _loadDebugImages(
  List<String> instructionAddresses, {
  bool automatedTestMode = false,
}) {
  final debugImageMaps = _loadDebugImageMaps(
    instructionAddresses,
    automatedTestMode: automatedTestMode,
  );
  return debugImageMaps?.map(DebugImage.fromJson).toList(growable: false);
}

List<Map<String, dynamic>>? _loadDebugImageMaps(
  List<String> instructionAddresses, {
  bool automatedTestMode = false,
}) {
  JSet<JString>? instructionAddressSet;
  final instructionAddressJStrings = <JString>[];
  JByteArray? imagesUtf8JsonBytes;

  try {
    for (final instructionAddress in instructionAddresses) {
      instructionAddressJStrings.add(instructionAddress.toJString());
    }

    instructionAddressSet = instructionAddressJStrings.toJSet(JString.type);

    imagesUtf8JsonBytes = native.SentryFlutterPlugin.loadDebugImagesAsBytes(
      instructionAddressSet,
    );
    if (imagesUtf8JsonBytes == null) return null;

    final byteRange = imagesUtf8JsonBytes.getRange(
      0,
      imagesUtf8JsonBytes.length,
    );
    final bytes = Uint8List.view(
      byteRange.buffer,
      byteRange.offsetInBytes,
      byteRange.length,
    );
    return decodeUtf8JsonListOfMaps(bytes);
  } catch (exception, stackTrace) {
    internalLogger.error(
      'JNI: Failed to load debug images',
      error: exception,
      stackTrace: stackTrace,
    );
    if (automatedTestMode) {
      rethrow;
    }
  } finally {
    for (final js in instructionAddressJStrings) {
      js.release();
    }
    instructionAddressSet?.release();
    imagesUtf8JsonBytes?.release();
  }

  return null;
}

Map<String, dynamic>? _loadContexts({bool automatedTestMode = false}) {
  JByteArray? contextsUtf8JsonBytes;

  try {
    contextsUtf8JsonBytes = native.SentryFlutterPlugin.loadContextsAsBytes();
    if (contextsUtf8JsonBytes == null) return null;

    final byteRange = contextsUtf8JsonBytes.getRange(
      0,
      contextsUtf8JsonBytes.length,
    );
    final bytes = Uint8List.view(
      byteRange.buffer,
      byteRange.offsetInBytes,
      byteRange.length,
    );
    return decodeUtf8JsonMap(bytes);
  } catch (exception, stackTrace) {
    internalLogger.error(
      'JNI: Failed to load contexts',
      error: exception,
      stackTrace: stackTrace,
    );
    if (automatedTestMode) {
      rethrow;
    }
  } finally {
    contextsUtf8JsonBytes?.release();
  }

  return null;
}

void _addBreadcrumb(
  Map<String, dynamic> breadcrumb, {
  bool automatedTestMode = false,
}) {
  JByteArray? jBytes;
  try {
    jBytes = _jsonToJByteArray(breadcrumb);
    native.SentryFlutterPlugin.addBreadcrumbFromJsonBytes(jBytes);
  } catch (exception, stackTrace) {
    internalLogger.error(
      'JNI: Failed to add breadcrumb',
      error: exception,
      stackTrace: stackTrace,
    );
    if (automatedTestMode) {
      rethrow;
    }
  } finally {
    jBytes?.release();
  }
}

void _clearBreadcrumbs({bool automatedTestMode = false}) {
  try {
    native.Sentry.clearBreadcrumbs();
  } catch (exception, stackTrace) {
    internalLogger.error(
      'JNI: Failed to clear breadcrumbs',
      error: exception,
      stackTrace: stackTrace,
    );
    if (automatedTestMode) {
      rethrow;
    }
  }
}

void _setUser(Map<String, dynamic>? user, {bool automatedTestMode = false}) {
  JByteArray? jBytes;
  try {
    if (user == null) {
      native.SentryFlutterPlugin.setUserFromJsonBytes(null);
    } else {
      jBytes = _jsonToJByteArray(user);
      native.SentryFlutterPlugin.setUserFromJsonBytes(jBytes);
    }
  } catch (exception, stackTrace) {
    internalLogger.error(
      'JNI: Failed to set user',
      error: exception,
      stackTrace: stackTrace,
    );
    if (automatedTestMode) {
      rethrow;
    }
  } finally {
    jBytes?.release();
  }
}

void _setContexts(String key, Object? value, {bool automatedTestMode = false}) {
  JString? jKey;
  JByteArray? jBytes;
  try {
    jKey = key.toJString();
    jBytes = _jsonToJByteArray(value);

    native.SentryFlutterPlugin.setContextFromJsonBytes(jKey, jBytes);
  } catch (exception, stackTrace) {
    internalLogger.error(
      'JNI: Failed to set context',
      error: exception,
      stackTrace: stackTrace,
    );
    if (automatedTestMode) {
      rethrow;
    }
  } finally {
    jKey?.release();
    jBytes?.release();
  }
}

void _removeContexts(String key, {bool automatedTestMode = false}) {
  JString? jKey;
  try {
    jKey = key.toJString();
    native.SentryFlutterPlugin.removeContext(jKey);
  } catch (exception, stackTrace) {
    internalLogger.error(
      'JNI: Failed to remove context',
      error: exception,
      stackTrace: stackTrace,
    );
    if (automatedTestMode) {
      rethrow;
    }
  } finally {
    jKey?.release();
  }
}

JByteArray _jsonToJByteArray(Object? value) =>
    JByteArray.from(encodeUtf8Json(normalize(value)));
