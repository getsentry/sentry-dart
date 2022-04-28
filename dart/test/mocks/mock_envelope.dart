import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_envelope_header.dart';
import 'package:sentry/src/client_reports/client_report.dart';

class MockEnvelope implements SentryEnvelope {
  ClientReport? clientReport;

  @override
  void addClientReport(ClientReport? clientReport) {
    this.clientReport = clientReport;
  }

  @override
  Stream<List<int>> envelopeStream(SentryOptions options) async* {
    yield [0];
  }

  @override
  SentryEnvelopeHeader get header => SentryEnvelopeHeader(
        SentryId.empty(),
        SdkVersion(name: 'fixture-name', version: '1'),
      );

  @override
  List<SentryEnvelopeItem> items = [];
}
