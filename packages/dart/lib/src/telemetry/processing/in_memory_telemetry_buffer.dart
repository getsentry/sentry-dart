import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry.dart';
import 'telemetry_buffer.dart';
import 'telemetry_buffer_config.dart';

typedef OnFlushCallback<T> = FutureOr<void> Function(T data);
typedef ItemEncoder<T> = List<int> Function(T item);
typedef GroupKeyExtractor<T> = String Function(T item);

abstract class _BaseInMemoryTelemetryBuffer<T, S> extends TelemetryBuffer<T> {
  S _storage;
  int _bufferSize = 0;
  int _itemCount = 0;
  Timer? _flushTimer;

  final TelemetryBufferConfig _config;
  final SdkLogCallback _logger;
  final ItemEncoder<T> _encoder;
  final OnFlushCallback<S> _onFlush;

  _BaseInMemoryTelemetryBuffer({
    required SdkLogCallback logger,
    required ItemEncoder<T> encoder,
    required OnFlushCallback<S> onFlush,
    required S initialStorage,
    TelemetryBufferConfig config = const TelemetryBufferConfig(),
  })  : _logger = logger,
        _encoder = encoder,
        _onFlush = onFlush,
        _storage = initialStorage,
        _config = config;

  S _createEmptyStorage();
  void _store(List<int> encoded, T item);
  bool get _isEmpty;

  bool get _isBufferFull =>
      _bufferSize >= _config.maxBufferSizeBytes ||
      _itemCount >= _config.maxItemCount;

  @override
  void add(T item) {
    final List<int> encoded;
    try {
      encoded = _encoder(item);
    } catch (exception, stackTrace) {
      _logger(SentryLevel.error, '$runtimeType: Failed to encode item $item',
          exception: exception, stackTrace: stackTrace);
      return;
    }

    if (encoded.length > _config.maxBufferSizeBytes) {
      _logger(
          SentryLevel.warning, '$runtimeType: Item exceeds max size, dropping');
      return;
    }

    _store(encoded, item);
    _bufferSize += encoded.length;
    _itemCount += 1;

    if (_isBufferFull) {
      flush();
    } else {
      _flushTimer ??= Timer(_config.flushTimeout, flush);
    }
  }

  @override
  FutureOr<void> flush() {
    _flushTimer?.cancel();
    _flushTimer = null;

    if (_isEmpty) return null;

    final toFlush = _storage;
    _storage = _createEmptyStorage();
    _bufferSize = 0;
    _itemCount = 0;

    try {
      return switch (_onFlush(toFlush)) {
        Future<void> f => f.catchError((exception, stackTrace) {
            _logger(SentryLevel.error, '$runtimeType: onFlush failed',
                exception: exception, stackTrace: stackTrace);
          }),
        _ => null,
      };
    } catch (exception, stackTrace) {
      _logger(SentryLevel.error, '$runtimeType: onFlush failed',
          exception: exception, stackTrace: stackTrace);
      return null;
    }
  }
}

class InMemoryTelemetryBuffer<T>
    extends _BaseInMemoryTelemetryBuffer<T, List<List<int>>> {
  InMemoryTelemetryBuffer({
    required super.logger,
    required super.encoder,
    required super.onFlush,
    super.config,
  }) : super(initialStorage: []);

  @override
  List<List<int>> _createEmptyStorage() => [];

  @override
  void _store(List<int> encoded, T item) => _storage.add(encoded);

  @override
  bool get _isEmpty => _storage.isEmpty;
}

class GroupedInMemoryTelemetryBuffer<T>
    extends _BaseInMemoryTelemetryBuffer<T, Map<String, List<List<int>>>> {
  final GroupKeyExtractor<T> _groupKey;

  @visibleForTesting
  GroupKeyExtractor<T> get groupKey => _groupKey;

  GroupedInMemoryTelemetryBuffer({
    required super.logger,
    required super.encoder,
    required super.onFlush,
    required GroupKeyExtractor<T> groupKeyExtractor,
    super.config,
  })  : _groupKey = groupKeyExtractor,
        super(initialStorage: {});

  @override
  Map<String, List<List<int>>> _createEmptyStorage() => {};

  @override
  void _store(List<int> encoded, T item) =>
      (_storage[_groupKey(item)] ??= []).add(encoded);

  @override
  bool get _isEmpty => _storage.isEmpty;
}
