import 'dart:async';

import 'package:meta/meta.dart';

import '../../utils/internal_logger.dart';
import 'buffer.dart';
import 'buffer_config.dart';

/// Callback invoked when the buffer is flushed with the accumulated data.
typedef OnFlushCallback<T> = FutureOr<void> Function(T data);

/// Encodes an item of type [T] into bytes.
typedef ItemEncoder<T> = List<int> Function(T item);

/// Why the buffer rejected an item.
enum BufferDropCause {
  /// The item could not be encoded (the encoder threw).
  encodeFailed,

  /// The encoded item exceeds the buffer's maximum size.
  tooLarge,
}

/// Callback invoked when the buffer drops an item before buffering it.
///
/// [bytes] is the encoded size of the item, or null when the size is unknown
/// because the item was never encoded, i.e. when [cause] is
/// [BufferDropCause.encodeFailed].
typedef OnDropCallback<T> = void Function(
  T item, {
  required BufferDropCause cause,
  int? bytes,
});

/// Base class for in-memory telemetry buffers.
///
/// Buffers telemetry items in memory and flushes them when either the
/// configured size limit, item count limit, or flush timeout is reached.
abstract base class _BaseInMemoryTelemetryBuffer<T, S>
    implements TelemetryBuffer<T> {
  final TelemetryBufferConfig _config;
  final ItemEncoder<T> _encoder;
  final OnFlushCallback<S> _onFlush;
  final OnDropCallback<T>? _onDrop;

  S _storage;
  int _bufferSize = 0;
  int _itemCount = 0;
  Timer? _flushTimer;

  _BaseInMemoryTelemetryBuffer({
    required ItemEncoder<T> encoder,
    required OnFlushCallback<S> onFlush,
    required S initialStorage,
    OnDropCallback<T>? onDrop,
    TelemetryBufferConfig config = const TelemetryBufferConfig(),
  })  : _encoder = encoder,
        _onFlush = onFlush,
        _onDrop = onDrop,
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
      internalLogger.error(
        '$runtimeType: Failed to encode item, dropping',
        error: exception,
        stackTrace: stackTrace,
      );
      _onDrop?.call(item, cause: BufferDropCause.encodeFailed);
      return;
    }

    if (encoded.length > _config.maxBufferSizeBytes) {
      internalLogger.warning(
        '$runtimeType: Item size ${encoded.length} exceeds buffer limit ${_config.maxBufferSizeBytes}, dropping',
      );
      _onDrop?.call(item,
          cause: BufferDropCause.tooLarge, bytes: encoded.length);
      return;
    }

    _store(encoded, item);
    _bufferSize += encoded.length;
    _itemCount++;

    if (_isBufferFull) {
      internalLogger.debug(
        '$runtimeType: Buffer full, flushing $_itemCount items',
      );
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
          (_) => internalLogger.debug(successMessage),
          onError: (exception, stackTrace) => internalLogger.warning(
            errorMessage,
            error: exception,
            stackTrace: stackTrace,
          ),
        );
      }
      internalLogger.debug(successMessage);
    } catch (exception, stackTrace) {
      internalLogger.warning(
        errorMessage,
        error: exception,
        stackTrace: stackTrace,
      );
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
    required super.encoder,
    required super.onFlush,
    super.onDrop,
    super.config,
  }) : super(initialStorage: []);

  @override
  List<List<int>> _createEmptyStorage() => [];

  @override
  void _store(List<int> encoded, T item) => _storage.add(encoded);

  @override
  bool get _isEmpty => _storage.isEmpty;
}

/// Extracts a grouping key from items of type [T].
typedef GroupKeyExtractor<T> = String Function(T item);

/// In-memory buffer that groups telemetry items by a key.
///
/// Same idea as [InMemoryTelemetryBuffer], but grouped.
final class GroupedInMemoryTelemetryBuffer<T>
    extends _BaseInMemoryTelemetryBuffer<T, Map<String, (List<List<int>>, T)>> {
  final GroupKeyExtractor<T> _groupKey;

  @visibleForTesting
  GroupKeyExtractor<T> get groupKey => _groupKey;

  GroupedInMemoryTelemetryBuffer({
    required super.encoder,
    required super.onFlush,
    required GroupKeyExtractor<T> groupKeyExtractor,
    super.onDrop,
    super.config,
  })  : _groupKey = groupKeyExtractor,
        super(initialStorage: {});

  @override
  Map<String, (List<List<int>>, T)> _createEmptyStorage() => {};

  @override
  void _store(List<int> encoded, T item) {
    final key = _groupKey(item);
    final bucket = _storage.putIfAbsent(key, () => ([], item));
    bucket.$1.add(encoded);
  }

  @override
  bool get _isEmpty => _storage.isEmpty;
}
