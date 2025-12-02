import 'dart:async';

import '../sentry.dart';

class InMemorySpanBuffer {
  InMemorySpanBuffer(
    this._options, {
    Duration? flushTimeout,
    int? maxBufferSizeBytes,
  })  : _flushTimeout = flushTimeout ?? Duration(seconds: 5),
        _maxBufferSizeBytes =
            maxBufferSizeBytes ?? 1024 * 1024; // 1MB default per spec

  final SentryOptions _options;
  final Duration _flushTimeout;
  final int _maxBufferSizeBytes;

  // Store encoded log data instead of raw spans to avoid re-serialization
  final List<List<int>> _encodedSpans = [];
  int _encodedSpansSize = 0;

  Timer? _flushTimer;

  /// Adds a span to the buffer.
  void add(Span span) {
    try {
      final encodedSpan = utf8JsonEncoder.convert(span.toJson());
      print(span.toJson());

      _encodedSpans.add(encodedSpan);
      _encodedSpansSize += encodedSpan.length;

      // Flush if size threshold is reached
      if (_encodedSpansSize >= _maxBufferSizeBytes) {
        // Buffer size exceeded, flush immediately
        _performFlush();
      } else if (_flushTimer == null) {
        // Start timeout only when first item is added
        _startTimer();
      }
      // Note: We don't restart the timer on subsequent additions per spec
    } catch (error) {
      _options.log(
        SentryLevel.error,
        'Failed to encode span: $error',
      );
    }
  }

  /// Flushes the buffer immediately, sending all buffered spans.
  FutureOr<void> flush() => _performFlush();

  void _startTimer() {
    _flushTimer = Timer(_flushTimeout, () {
      _options.log(
        SentryLevel.debug,
        '$InMemorySpanBuffer: Timer fired, flushing buffer.',
      );
      _performFlush();
    });
  }

  FutureOr<void> _performFlush() {
    // Reset timer state first
    _flushTimer?.cancel();
    _flushTimer = null;

    // Reset buffer on function exit
    final spansToSend = List<List<int>>.from(_encodedSpans);
    _encodedSpans.clear();
    _encodedSpansSize = 0;

    if (spansToSend.isEmpty) {
      _options.log(
        SentryLevel.debug,
        '$InMemorySpanBuffer: No spans to flush.',
      );
    } else {
      try {
        final traceContext = SentryTraceContextHeader(
          Sentry.currentHub.scope.propagationContext.traceId,
          _options.parsedDsn.publicKey,
        );
        final envelope = SentryEnvelope.fromSpansData(spansToSend, _options.sdk,
            dsn: _options.dsn, traceContext: traceContext);
        return _options.transport.send(envelope).then((_) => null);
      } catch (error) {
        _options.log(
          SentryLevel.error,
          'Failed to create envelope for batched spans: $error',
        );
      }
    }
  }
}
