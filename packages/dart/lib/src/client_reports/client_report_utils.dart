import 'dart:math';

import 'package:meta/meta.dart';

import '../telemetry/log/log.dart';
import '../transport/data_category.dart';
import '../utils.dart';
import 'client_report_recorder.dart';
import 'discard_reason.dart';

@internal
void recordLostLog(
  ClientReportRecorder recorder,
  DiscardReason reason, {
  int count = 1,
  required int bytes,
}) {
  recorder.recordLostEvent(reason, DataCategory.logItem, count: count);
  recorder.recordLostEvent(reason, DataCategory.logByte, count: max(bytes, 0));
}

@internal
int approximateLogBytes(SentryLog log) {
  return utf8JsonEncoder.convert(log.toJson()).length;
}
