import 'dart:async';
import 'sentry_envelope.dart';
import 'sentry_options.dart';
import 'protocol/sentry_log.dart';

class SentryLogBatcher {
  SentryLogBatcher(this._options, {Duration? flushTimeout, int? maxBufferSize})
      : _flushTimeout = flushTimeout ?? Duration(seconds: 5),
        _maxBufferSize = maxBufferSize ?? 100;

  final SentryOptions _options;
  final Duration _flushTimeout;
  final int _maxBufferSize;

  final _logBuffer = <SentryLog>[];

  Timer? _flushTimer;

  FutureOr<void> addLog(SentryLog log) async {
    _logBuffer.add(log);

    _flushTimer?.cancel();

    if (_logBuffer.length >= _maxBufferSize) {
      return flush();
    } else {
      _flushTimer = Timer(_flushTimeout, flush);
    }
  }

  Future<void> flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;

    final logs = List<SentryLog>.from(_logBuffer);
    _logBuffer.clear();

    if (logs.isEmpty) {
      return;
    }

    final envelope = SentryEnvelope.fromLogs(
      logs,
      _options.sdk,
    );

    await _options.transport.send(envelope);
  }
}
