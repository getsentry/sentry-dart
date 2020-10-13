import 'dart:collection';

import 'protocol.dart';
import 'sentry_options.dart';

/// Scope data to be sent with the event
class Scope {
  /// How important this event is.
  SeverityLevel level;

  /// The name of the transaction which generated this event,
  /// for example, the route name: `"/users/<username>/"`.
  String transaction;

  /// Information about the current user.
  User user;

  /// Used to deduplicate events by grouping ones with the same fingerprint
  /// together.
  ///
  /// Example:
  ///
  ///     // A completely custom fingerprint:
  ///     var custom = ['foo', 'bar', 'baz'];
  List<String> fingerprint;

  /// List of breadcrumbs for this scope.
  ///
  /// See also:
  /// * https://docs.sentry.io/enriching-error-data/breadcrumbs/?platform=javascript
  final Queue<Breadcrumb> _breadcrumbs = Queue();

  /// Unmodifiable List of breadcrumbs
  List<Breadcrumb> get breadcrumbs => List.unmodifiable(_breadcrumbs);

  /// Name/value pairs that events can be searched by.
  final Map<String, String> tags = {};

  /// Arbitrary name/value pairs attached to the scope.
  ///
  /// Sentry.io docs do not talk about restrictions on the values, other than
  /// they must be JSON-serializable.
  final Map<String, dynamic> extra = {};

  // TODO: eventProcessors, Contexts, BeforeBreadcrumbCallback, Breadcrumb hint, clone

  final SentryOptions _options;

  Scope(this._options) : assert(_options != null, 'SentryOptions is required');

  /// Adds a breadcrumb to the breadcrumbs queue
  void addBreadcrumb(Breadcrumb breadcrumb) {
    assert(breadcrumb != null, "Breadcrumb can't be null");

    // bail out if maxBreadcrumbs is zero
    if (_options.maxBreadcrumbs == 0) {
      return;
    }

    // remove first item if list if full
    if (_breadcrumbs.length >= _options.maxBreadcrumbs &&
        _breadcrumbs.isNotEmpty) {
      _breadcrumbs.removeFirst();
    }

    _breadcrumbs.add(breadcrumb);
  }

  /// Clear all the breadcrumbs
  void clearBreadcrumbs() {
    _breadcrumbs.clear();
  }

  /// Resets the Scope to its default state
  void clear() {
    clearBreadcrumbs();
    level = null;
    transaction = null;
    user = null;
    fingerprint = null;
    tags.clear();
    extra.clear();
  }
}
