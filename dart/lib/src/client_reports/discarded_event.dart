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
      'reason': reason._toStringValue(),
      'category': category._toStringValue(),
      'quantity': quantity,
    };
  }
}

extension _OutcomeExtension on DiscardReason {
  String _toStringValue() {
    switch (this) {
      case DiscardReason.beforeSend:
        return 'before_send';
      case DiscardReason.eventProcessor:
        return 'event_processor';
      case DiscardReason.sampleRate:
        return 'sample_rate';
      case DiscardReason.networkError:
        return 'network_error';
      case DiscardReason.queueOverflow:
        return 'queue_overflow';
      case DiscardReason.cacheOverflow:
        return 'cache_overflow';
      case DiscardReason.rateLimitBackoff:
        return 'ratelimit_backoff';
    }
  }
}

extension _DataCategoryExtension on DataCategory {
  String _toStringValue() {
    switch (this) {
      case DataCategory.all:
        return '__all__';
      case DataCategory.dataCategoryDefault:
        return 'default';
      case DataCategory.error:
        return 'error';
      case DataCategory.session:
        return 'session';
      case DataCategory.transaction:
        return 'transaction';
      case DataCategory.attachment:
        return 'attachment';
      case DataCategory.security:
        return 'security';
      case DataCategory.unknown:
        return 'unknown';
      case DataCategory.metricBucket:
        return 'metric_bucket';
    }
  }
}
