import 'package:meta/meta.dart';
import '../../sentry.dart';
import '../client_reports/client_report_recorder.dart';
import 'rate_limiter.dart';

/// Decorator that handles attaching of client reports in tandem with rate
/// limiting. The rate limiter is optional.
@internal
class ClientReportTransport implements Transport {
  final RateLimiter? _rateLimiter;
  final ClientReportRecorder _recorder;

  final Transport _transport;

  ClientReportTransport(this._rateLimiter, this._recorder, this._transport);

  @visibleForTesting
  get rateLimiter => _rateLimiter;

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    final rateLimiter = _rateLimiter;

    SentryEnvelope? filteredEnvelope;
    if (rateLimiter != null) {
      filteredEnvelope = rateLimiter.filter(envelope);
      // TODO handle case where we send a client reports anyway if we were rate limited too many times
    } else {
      filteredEnvelope = envelope;
    }

    if (filteredEnvelope == null) {
      return SentryId.empty();
    }

    final clientReport = _recorder.flush();
    envelope.addClientReport(clientReport);

    return _transport.send(envelope);
  }
}
