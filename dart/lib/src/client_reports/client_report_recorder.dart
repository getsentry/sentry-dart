import 'package:meta/meta.dart';

import '../sentry_options.dart';
import 'client_report.dart';
import 'discarded_event.dart';
import 'discard_reason.dart';
import '../transport/data_category.dart';

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
