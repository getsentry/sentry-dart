import 'package:meta/meta.dart';

@internal
enum DiscardReason { ratelimitBackoff, networkError }

extension OutcomeExtension on DiscardReason {
  String toStringValue() {
    switch (this) {
      case DiscardReason.ratelimitBackoff:
        return 'ratelimit_backoff';
      case DiscardReason.networkError:
        return 'network_error';
    }
  }
}
