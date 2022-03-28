import 'package:meta/meta.dart';

import 'outcome.dart';
import '../transport/rate_limit_category.dart';

@internal
class DiscardedEvent {
  DiscardedEvent(this.reason, this.category, this.quantity);

  final Outcome reason;
  final RateLimitCategory category;
  final int quantity;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    json['reason'] = reason.toStringValue();
    json['category'] = category.toStringValue();
    json['quantity'] = quantity;

    return json;
  }
}
