import 'package:meta/meta.dart';

import 'outcome.dart';
import '../transport/data_category.dart';

@internal
class DiscardedEvent {
  DiscardedEvent(this.reason, this.category, this.quantity);

  final DiscardReason reason;
  final DataCategory category;
  final int quantity;
}
