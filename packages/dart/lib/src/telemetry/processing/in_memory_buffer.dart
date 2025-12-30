import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry.dart';
import 'buffer.dart';
import 'buffer_config.dart';

/// Callback invoked when the buffer is flushed with the accumulated data.
typedef OnFlushCallback<T> = FutureOr<void> Function(T data);

/// Encodes an item of type [T] into bytes.
typedef ItemEncoder<T> = List<int> Function(T item);

/// Extracts a grouping key from items of type [T].
typedef GroupKeyExtractor<T> = String Function(T item);

/// Base class for in-memory telemetry buffers.
///
/// Buffers telemetry items in memory and flushes them when either the
/// configured size limit, item count limit, or flush timeout is reached.
/// Subclasses define how items are stored and grouped.
abstract base class _BaseInMemoryTelemetryBuffer<T, S>
    implements TelemetryBuffer<T> {
  final TelemetryBufferConfig _config;
  final SdkLogCallback _logger;
  final ItemEncoder<T> _encoder;
  final OnFlushCallback<S> _onFlush;

  S _storage;
  int _bufferSize = 0;
  int _itemCount = 0;
  Timer? _flushTimer;

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
      _logger(
          SentryLevel.error, '$runtimeType: Failed to encode item, dropping',
          exception: exception, stackTrace: stackTrace);
      return;
    }

    if (encoded.length > _config.maxBufferSizeBytes) {
      _logger(SentryLevel.warning,
          '$runtimeType: Item size ${encoded.length} exceeds buffer limit ${_config.maxBufferSizeBytes}, dropping');
      return;
    }

    _store(encoded, item);
    _bufferSize += encoded.length;
    _itemCount++;

    if (_isBufferFull) {
      _logger(SentryLevel.debug,
          '$runtimeType: Buffer full, flushing $_itemCount items');
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
    final flushedCount = _itemCount;
    final flushedSize = _bufferSize;
    _storage = _createEmptyStorage();
    _bufferSize = 0;
    _itemCount = 0;

    final successMessage =
        '$runtimeType: Flushed $flushedCount items ($flushedSize bytes)';
    final errorMessage =
        '$runtimeType: Flush failed for $flushedCount items ($flushedSize bytes)';

    try {
      final result = _onFlush(toFlush);
      if (result is Future) {
        return result.then(
          (_) => _logger(SentryLevel.debug, successMessage),
          onError: (exception, stackTrace) => _logger(
              SentryLevel.warning, errorMessage,
              exception: exception, stackTrace: stackTrace),
        );
      }
      _logger(SentryLevel.debug, successMessage);
    } catch (exception, stackTrace) {
      _logger(SentryLevel.warning, errorMessage,
          exception: exception, stackTrace: stackTrace);
    }
  }
}

/// In-memory buffer that collects telemetry items as a flat list.
///
/// Items are encoded and stored in insertion order. On flush, the entire
/// list of encoded items is passed to the [OnFlushCallback].
final class InMemoryTelemetryBuffer<T>
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

/// In-memory buffer that groups telemetry items by a key.
///
/// Items are organized into groups based on the [groupKeyExtractor] function.
/// On flush, a map of group keys to their encoded items is passed to the
/// [OnFlushCallback]. This is useful for batching items that should be grouped
/// together, such as spans with the same trace ID.
final class GroupedInMemoryTelemetryBuffer<T>
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
      (_storage.putIfAbsent(_groupKey(item), () => [])).add(encoded);

  @override
  bool get _isEmpty => _storage.isEmpty;
}
