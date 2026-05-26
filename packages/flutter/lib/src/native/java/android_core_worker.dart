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
    } finally {
      _startFuture = null;
    }
  }

  FutureOr<void> close() {
    _worker?.close();
    _worker = null;
    _isClosed = true;
  }

  void captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException) {
    if (_isClosed) return;

    final client = _worker;
    if (client == null) {
      internalLogger.info(
        'captureEnvelope called before core worker started: sending envelope in main isolate instead',
      );
      _captureEnvelope(envelopeData, containsUnhandledException,
          automatedTestMode: _config.automatedTestMode);
      return;
    }

    _captureEnvelopeFromWorker(
        client, envelopeData, containsUnhandledException);
  }

  void _captureEnvelopeFromWorker(
    Worker client,
    Uint8List envelopeData,
    bool containsUnhandledException,
  ) {
    client.send(_CaptureEnvelopeRequest(
      TransferableTypedData.fromList([envelopeData]),
      containsUnhandledException,
    ));
  }

  FutureOr<List<DebugImage>?> loadDebugImages(SentryStackTrace stackTrace) {
    final instructionAddresses =
        stackTrace.frames.map((f) => f.instructionAddr).nonNulls.toList(
              growable: false,
            );

    final client = _worker;
    if (client == null) {
      return _loadDebugImages(instructionAddresses,
          automatedTestMode: _config.automatedTestMode);
    }

    return _loadDebugImagesFromWorker(client, instructionAddresses);
  }

  Future<List<DebugImage>?> _loadDebugImagesFromWorker(
    Worker client,
    List<String> instructionAddresses,
  ) async {
    try {
      final response =
          await client.request(_LoadDebugImagesRequest(instructionAddresses));
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
      _addBreadcrumb(breadcrumb.toJson(),
          automatedTestMode: _config.automatedTestMode);
      return null;
    }

    return _addBreadcrumbFromWorker(client, breadcrumb);
  }

  Future<void> _addBreadcrumbFromWorker(
    Worker client,
    Breadcrumb breadcrumb,
  ) =>
      _sendScopeUpdateToWorker(
        client,
        _AddBreadcrumbRequest(_normalizeJsonMap(breadcrumb.toJson())),
        'add breadcrumb',
      );

  FutureOr<void> setUser(SentryUser? user) {
    if (_isClosed) return null;

    final client = _worker;
    if (client == null) {
      _setUser(user?.toJson(), automatedTestMode: _config.automatedTestMode);
      return null;
    }

    return _setUserFromWorker(client, user);
  }

  Future<void> _setUserFromWorker(
    Worker client,
    SentryUser? user,
  ) =>
      _sendScopeUpdateToWorker(
        client,
        _SetUserRequest(
          user == null ? null : _normalizeJsonMap(user.toJson()),
        ),
        'set user',
      );

  FutureOr<void> setContexts(String key, dynamic value) {
    if (_isClosed) return null;

    final normalizedValue = _normalizeJson(value);
    final client = _worker;
    if (client == null) {
      _setContexts(key, normalizedValue,
          automatedTestMode: _config.automatedTestMode);
      return null;
    }

    return _setContextsFromWorker(client, key, normalizedValue);
  }

  Future<void> _setContextsFromWorker(
    Worker client,
    String key,
    Object? value,
  ) =>
      _sendScopeUpdateToWorker(
        client,
        _SetContextsRequest(key, value),
        'set context',
      );

  Future<void> _sendScopeUpdateToWorker(
    Worker client,
    Object request,
    String operation,
  ) async {
    try {
      await client.request(request);
    } catch (exception, stackTrace) {
      internalLogger.error(
        'Android core worker failed to $operation',
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
            _captureEnvelope(data, request.containsUnhandledException,
                automatedTestMode: _config.automatedTestMode);
          case _AddBreadcrumbRequest request:
            _addBreadcrumb(request.breadcrumb,
                automatedTestMode: _config.automatedTestMode);
          case _SetUserRequest request:
            _setUser(request.user,
                automatedTestMode: _config.automatedTestMode);
          case _SetContextsRequest request:
            _setContexts(request.key, request.value,
                automatedTestMode: _config.automatedTestMode);
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
            _addBreadcrumb(request.breadcrumb,
                automatedTestMode: _config.automatedTestMode);
            return null;
          case _SetUserRequest request:
            _setUser(request.user,
                automatedTestMode: _config.automatedTestMode);
            return null;
          case _SetContextsRequest request:
            _setContexts(request.key, request.value,
                automatedTestMode: _config.automatedTestMode);
            return null;
          default:
            return _unexpectedPayload(payload);
        }
      });

  /// Serializes JNI work inside the worker isolate.
  Future<T> _enqueue<T>(FutureOr<T> Function() action) {
    final next = _queue.then((_) => action());
    _queue = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  Object? _unexpectedPayload(Object? payload) {
    internalLogger
        .warning('${_config.debugName}: unexpected payload type: $payload');
    return null;
  }

  void _unexpectedMessage(Object? msg) {
    internalLogger
        .warning('${_config.debugName}: unexpected message type: $msg');
  }
}

class _CaptureEnvelopeRequest {
  final TransferableTypedData envelopeData;
  final bool containsUnhandledException;

  const _CaptureEnvelopeRequest(
      this.envelopeData, this.containsUnhandledException);
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

class _SetUserRequest {
  final Map<String, dynamic>? user;

  const _SetUserRequest(this.user);
}

class _SetContextsRequest {
  final String key;
  final Object? value;

  const _SetContextsRequest(this.key, this.value);
}

void _captureEnvelope(Uint8List envelopeData, bool containsUnhandledException,
    {bool automatedTestMode = false}) {
  JObject? id;
  JByteArray? byteArray;
  try {
    byteArray = JByteArray.from(envelopeData);
    id = native.InternalSentrySdk.captureEnvelope(
        byteArray, containsUnhandledException);

    if (id == null) {
      internalLogger
          .error('Native Android SDK returned null when capturing envelope');
    }
  } catch (exception, stackTrace) {
    internalLogger.error('Failed to capture envelope',
        error: exception, stackTrace: stackTrace);
    if (automatedTestMode) {
      rethrow;
    }
  } finally {
    byteArray?.release();
    id?.release();
  }
}

List<DebugImage>? _loadDebugImages(List<String> instructionAddresses,
    {bool automatedTestMode = false}) {
  final debugImageMaps = _loadDebugImageMaps(instructionAddresses,
      automatedTestMode: automatedTestMode);
  return debugImageMaps?.map(DebugImage.fromJson).toList(growable: false);
}

List<Map<String, dynamic>>? _loadDebugImageMaps(
    List<String> instructionAddresses,
    {bool automatedTestMode = false}) {
  JSet<JString>? instructionAddressSet;
  final instructionAddressJStrings = <JString>[];
  JByteArray? imagesUtf8JsonBytes;

  try {
    for (final instructionAddress in instructionAddresses) {
      instructionAddressJStrings.add(instructionAddress.toJString());
    }

    instructionAddressSet = instructionAddressJStrings.toJSet(JString.type);

    imagesUtf8JsonBytes = native.SentryFlutterPlugin.loadDebugImagesAsBytes(
        instructionAddressSet);
    if (imagesUtf8JsonBytes == null) return null;

    final byteRange =
        imagesUtf8JsonBytes.getRange(0, imagesUtf8JsonBytes.length);
    final bytes = Uint8List.view(
        byteRange.buffer, byteRange.offsetInBytes, byteRange.length);
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

    final byteRange =
        contextsUtf8JsonBytes.getRange(0, contextsUtf8JsonBytes.length);
    final bytes = Uint8List.view(
        byteRange.buffer, byteRange.offsetInBytes, byteRange.length);
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

void _addBreadcrumb(Map<String, dynamic> breadcrumb,
    {bool automatedTestMode = false}) {
  JByteArray? jBytes;
  try {
    jBytes = _jsonToJByteArray(breadcrumb);
    native.SentryFlutterPlugin.addBreadcrumbFromJsonBytes(jBytes);
  } catch (exception, stackTrace) {
    internalLogger.error('JNI: Failed to add breadcrumb',
        error: exception, stackTrace: stackTrace);
    if (automatedTestMode) {
      rethrow;
    }
  } finally {
    jBytes?.release();
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
    internalLogger.error('JNI: Failed to set user',
        error: exception, stackTrace: stackTrace);
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
    internalLogger.error('JNI: Failed to set context',
        error: exception, stackTrace: stackTrace);
    if (automatedTestMode) {
      rethrow;
    }
  } finally {
    jKey?.release();
    jBytes?.release();
  }
}

JByteArray _jsonToJByteArray(Object? value) =>
    JByteArray.from(encodeUtf8Json(_normalizeJson(value)));

Map<String, dynamic> _normalizeJsonMap(Map<String, dynamic> value) =>
    _normalizeJson(value) as Map<String, dynamic>;

Object? _normalizeJson(Object? value) {
  if (value is Map) {
    return value.map(
      (key, value) => MapEntry(key.toString(), _normalizeJson(value)),
    );
  }
  if (value is List) {
    return value.map(_normalizeJson).toList(growable: false);
  }
  return normalize(value);
}
