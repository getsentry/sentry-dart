enum Outcome { ratelimitBackoff, networkError }

extension OutcomeExtension on Outcome {
  String toStringValue() {
    switch (this) {
      case Outcome.ratelimitBackoff:
        return 'ratelimit_backoff';
      case Outcome.networkError:
        return 'network_error';
    }
  }
}
