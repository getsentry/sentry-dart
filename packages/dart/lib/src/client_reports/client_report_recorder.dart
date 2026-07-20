import 'package:meta/meta.dart';

import '../sentry_options.dart';
import '../transport/data_category.dart';
import 'client_report.dart';
import 'discarded_event.dart';
import 'discard_reason.dart';

@internal
class ClientReportRecorder {
  ClientReportRecorder(this._clock);

  final ClockProvider _clock;
  final Map<_QuantityKey, int> _quantities = {};

  void recordLostEvent(final DiscardReason reason, final DataCategory category,
      {int count = 1}) {
    final key = _QuantityKey(reason, category);
    var current = _quantities[key] ?? 0;
    _quantities[key] = current + count;
  }

  /// Records a dropped log as a [DataCategory.logItem] count and, when the
  /// size is known, an additional [DataCategory.logByte] outcome as required
  /// by the client reports spec for log byte outcomes.
  ///
  /// Pass a null [bytes] when the size cannot be determined (e.g. the log
  /// could not be encoded); the [DataCategory.logByte] outcome is then omitted
  /// rather than reported as zero.
  void recordLostLog(final DiscardReason reason, {int count = 1, int? bytes}) {
    recordLostEvent(reason, DataCategory.logItem, count: count);
    if (bytes != null) {
      recordLostEvent(reason, DataCategory.logByte, count: bytes);
    }
  }

  /// Records dropped metrics as a [DataCategory.metric] count and, when the
  /// size is known, an additional [DataCategory.metricByte] outcome.
  ///
  /// Pass a null [bytes] when the size cannot be determined. The byte outcome
  /// is then omitted rather than reported as zero.
  void recordLostMetric(final DiscardReason reason,
      {int count = 1, int? bytes}) {
    recordLostEvent(reason, DataCategory.metric, count: count);
    if (bytes != null) {
      recordLostEvent(reason, DataCategory.metricByte, count: bytes);
    }
  }

  ClientReport? flush() {
    if (_quantities.isEmpty) {
      return null;
    }

    final events = _quantities.keys.map((key) {
      final quantity = _quantities[key] ?? 0;
      return DiscardedEvent(key.reason, key.category, quantity);
    }).toList(growable: false);

    _quantities.clear();

    return ClientReport(_clock(), events);
  }
}

class _QuantityKey {
  _QuantityKey(this.reason, this.category);

  final DiscardReason reason;
  final DataCategory category;

  @override
  int get hashCode => Object.hash(reason.hashCode, category.hashCode);

  @override
  // ignore: non_nullable_equals_parameter
  bool operator ==(dynamic other) {
    return other is _QuantityKey &&
        other.reason == reason &&
        other.category == category;
  }
}
