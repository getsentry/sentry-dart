import 'package:sentry/sentry.dart';
import 'package:sentry/src/client_reports/discard_reason.dart';
import 'package:sentry/src/transport/data_category.dart';

class MockClientReportRecorder implements ClientReportRecorder {
  DiscardReason? reason;
  DataCategory? category;

  ClientReport? clientReport;

  bool flushCalled = false;

  @override
  ClientReport? flush() {
    flushCalled = true;
    return clientReport;
  }

  @override
  void recordLostEvent(DiscardReason reason, DataCategory category) {
    this.reason = reason;
    this.category = category;
  }
}
