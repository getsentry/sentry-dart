import 'package:meta/meta.dart';

import '../utils.dart';
import 'client_report.dart';
import 'discarded_event.dart';
import 'outcome.dart';
import '../transport/rate_limit_category.dart';

@internal
class ClientReportRecorder {
  ClientReportRecorder([this._dateTimeProvider = getUtcDateTime]);

  final DateTime Function() _dateTimeProvider;
  final Map<_ClientReportKey, int> _quantities = {};

  void recordLostEvent(final Outcome reason, final RateLimitCategory category) {
    final key = _ClientReportKey(reason, category);
    var current = _quantities[key] ?? 0;
    _quantities[key] = current + 1;
  }

  ClientReport? flush() {
    if (_quantities.isEmpty) {
      return null;
    }

    final events = _quantities.keys.map((key) {
      final quantity = _quantities[key] ?? 0;
      return DiscardedEvent(key.reason, key.category, quantity);
    }).toList();

    _quantities.clear();

    return ClientReport(_dateTimeProvider(), events);
  }
}

class _ClientReportKey {
  _ClientReportKey(this.reason, this.category);

  final Outcome reason;
  final RateLimitCategory category;

  @override
  int get hashCode => Object.hash(reason, category);

  @override
  bool operator ==(dynamic other) {
    return other is _ClientReportKey &&
        other.reason == reason &&
        other.category == category;
  }
}
