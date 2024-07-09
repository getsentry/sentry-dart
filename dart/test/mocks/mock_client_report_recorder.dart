import 'package:sentry/src/client_reports/client_report_recorder.dart';
import 'package:sentry/src/client_reports/discard_reason.dart';
import 'package:sentry/src/client_reports/client_report.dart';
import 'package:sentry/src/client_reports/discarded_event.dart';
import 'package:sentry/src/transport/data_category.dart';

class MockClientReportRecorder implements ClientReportRecorder {
  List<DiscardedEvent> discardedEvents = [];

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
  void recordLostEvent(DiscardReason reason, DataCategory category,
      {int count = 1}) {
    this.reason = reason;
    this.category = category;
    discardedEvents.add(DiscardedEvent(reason, category, count));
  }
}
