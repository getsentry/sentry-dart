import 'package:meta/meta.dart';

import '../transport/data_category.dart';
import 'client_report.dart';
import 'client_report_recorder.dart';
import 'discard_reason.dart';

@internal
class NoOpClientReportRecorder implements ClientReportRecorder {
  const NoOpClientReportRecorder();

  @override
  ClientReport? flush() {
    return null;
  }

  @override
  void recordLostEvent(DiscardReason reason, DataCategory category,
      {int count = 1}) {}
}
