import 'package:meta/meta.dart';

import 'discard_reason.dart';
import '../transport/data_category.dart';

@internal
class DiscardedEvent {
  DiscardedEvent(this.reason, this.category, this.quantity);

  final DiscardReason reason;
  final DataCategory category;
  final int quantity;

  Map<String, dynamic> toJson() {
    return {
      'reason': reason.toStringValue(),
      'category': category.toStringValue(),
      'quantity': quantity,
    };
  }
}
