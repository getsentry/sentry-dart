import '../transport/rate_limit_parser.dart';

import '../sentry_options.dart';
import '../sentry_envelope.dart';
import '../sentry_envelope_item.dart';
import '../sentry_item_type.dart';
import 'rate_limit.dart';
import 'rate_limit_category.dart';

/// Controls retry limits on different category types sent to Sentry.
class RateLimiter {
  RateLimiter(this._clockProvider);

  final ClockProvider _clockProvider;
  final _rateLimitedUntil = <RateLimitCategory, DateTime>{};

  SentryEnvelope? filter(SentryEnvelope envelope) {
    // Optimize for/No allocations if no items are under 429
    List<SentryEnvelopeItem>? dropItems;
    for (final item in envelope.items) {
      // using the raw value of the enum to not expose SentryEnvelopeItemType
      if (_isRetryAfter(item.header.type.toStringValue())) {
        dropItems ??= [];
        dropItems.add(item);
      }
    }

    if (dropItems != null) {
      //logger.log(SentryLevel.INFO, "%d items will be dropped due rate limiting.", dropItems.size());

      // Need a new envelope
      final toSend = <SentryEnvelopeItem>[];
      for (final item in envelope.items) {
        if (!dropItems.contains(item)) {
          toSend.add(item);
        }
      }

      // no reason to continue
      if (toSend.isEmpty) {
        //logger.log(SentryLevel.INFO, "Envelope discarded due all items rate limited.");

        //markHintWhenSendingFailed(hint, false);
        return null;
      }

      return SentryEnvelope(envelope.header, toSend);
    } else {
      return envelope;
    }
  }

  void updateRetryAfterLimits(
      String? sentryRateLimitHeader, String? retryAfterHeader, int errorCode) {
    final currentDateTime = _clockProvider().millisecondsSinceEpoch;
    var rateLimits = <RateLimit>[];

    if (sentryRateLimitHeader != null) {
      rateLimits =
          RateLimitParser(sentryRateLimitHeader).parseRateLimitHeader();
    } else if (errorCode == 429) {
      rateLimits =
          RateLimitParser(sentryRateLimitHeader).parseRetryAfterHeader();
    }

    for (final rateLimit in rateLimits) {
      _applyRetryAfterOnlyIfLonger(
          rateLimit.category,
          DateTime.fromMillisecondsSinceEpoch(
              currentDateTime + rateLimit.durationInMillis));
    }
  }

  // Private

  bool _isRetryAfter(String itemType) {
    final dataCategory = _categoryFromItemType(itemType);
    final currentDate = DateTime.fromMillisecondsSinceEpoch(
      _clockProvider().millisecondsSinceEpoch
    );

    // check all categories
    final dateAllCategories = _rateLimitedUntil[RateLimitCategory.all];
    if (dateAllCategories != null) {
      if (!(currentDate.millisecondsSinceEpoch >
          dateAllCategories.millisecondsSinceEpoch)) {
        return true;
      }
    }

    // Unknown should not be rate limited
    if (RateLimitCategory.unknown == dataCategory) {
      return false;
    }

    // check for specific dataCategory
    final dateCategory = _rateLimitedUntil[dataCategory];
    if (dateCategory != null) {
      return !(currentDate.millisecondsSinceEpoch >
          dateCategory.millisecondsSinceEpoch);
    }

    return false;
  }

  RateLimitCategory _categoryFromItemType(String itemType) {
    switch (itemType) {
      case 'event':
        return RateLimitCategory.error;
      case 'session':
        return RateLimitCategory.session;
      case 'attachment':
        return RateLimitCategory.attachment;
      case 'transaction':
        return RateLimitCategory.transaction;
      default:
        return RateLimitCategory.unknown;
    }
  }

  void _applyRetryAfterOnlyIfLonger(
      RateLimitCategory rateLimitCategory, DateTime date) {
    final oldDate = _rateLimitedUntil[rateLimitCategory];

    // only overwrite its previous date if the limit is even longer
    if (oldDate == null ||
        date.millisecondsSinceEpoch > oldDate.millisecondsSinceEpoch) {
      _rateLimitedUntil[rateLimitCategory] = date;
    }
  }
}
