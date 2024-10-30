import 'package:meta/meta.dart';
import '../../sentry.dart';
import '../client_reports/client_report_recorder.dart';
import '../sentry_envelope_header.dart';
import 'rate_limiter.dart';

/// Decorator that handles attaching of client reports in tandem with rate
/// limiting. The rate limiter is optional.
@internal
class ClientReportTransport implements Transport {
  final RateLimiter? _rateLimiter;
  final SentryOptions _options;
  final Transport _transport;

  ClientReportTransport(this._rateLimiter, this._options, this._transport);

  @visibleForTesting
  get rateLimiter => _rateLimiter;

  int _numberOfDroppedEnvelopes = 0;

  @visibleForTesting
  get numberOfDroppedEvents => _numberOfDroppedEnvelopes;

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    final rateLimiter = _rateLimiter;

    SentryEnvelope? filteredEnvelope = envelope;
    if (rateLimiter != null) {
      filteredEnvelope = rateLimiter.filter(envelope);
    }
    if (filteredEnvelope == null) {
      _numberOfDroppedEnvelopes += 1;
    }
    if (_numberOfDroppedEnvelopes >= 10) {
      // Create new envelope that could only contain client reports
      filteredEnvelope = SentryEnvelope(
        SentryEnvelopeHeader(SentryId.newId(), _options.sdk),
        [],
      );
    }
    if (filteredEnvelope == null) {
      return SentryId.empty();
    }
    _numberOfDroppedEnvelopes = 0;

    final clientReport = _options.recorder.flush();
    filteredEnvelope.addClientReport(clientReport);

    if (filteredEnvelope.items.isNotEmpty) {
      return _transport.send(filteredEnvelope);
    } else {
      return SentryId.empty();
    }
  }
}
