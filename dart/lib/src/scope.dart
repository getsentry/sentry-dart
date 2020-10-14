import 'dart:collection';

import 'protocol.dart';
import 'sentry_options.dart';

/// Scope data to be sent with the event
class Scope {
  /// How important this event is.
  SeverityLevel _level;

  SeverityLevel get level => _level;

  set level(SeverityLevel level) {
    _level = level;
  }

  /// The name of the transaction which generated this event,
  /// for example, the route name: `"/users/<username>/"`.
  String _transaction;

  String get transaction => _transaction;

  set transaction(String transaction) {
    _transaction = transaction;
  }

  /// Information about the current user.
  User _user;

  User get user => _user;

  set user(User user) {
    _user = user;
  }

  /// Used to deduplicate events by grouping ones with the same fingerprint
  /// together.
  ///
  /// Example:
  ///
  ///     // A completely custom fingerprint:
  ///     var custom = ['foo', 'bar', 'baz'];
  List<String> _fingerprint;

  List<String> get fingerprint =>
      _fingerprint != null ? List.unmodifiable(_fingerprint) : null;

  set fingerprint(List<String> fingerprint) {
    _fingerprint = fingerprint;
  }

  /// List of breadcrumbs for this scope.
  ///
  /// See also:
  /// * https://docs.sentry.io/enriching-error-data/breadcrumbs/?platform=javascript
  final Queue<Breadcrumb> _breadcrumbs = Queue();

  /// Unmodifiable List of breadcrumbs
  List<Breadcrumb> get breadcrumbs => List.unmodifiable(_breadcrumbs);

  /// Name/value pairs that events can be searched by.
  final Map<String, String> _tags = {};

  Map<String, String> get tags => Map.unmodifiable(_tags);

  /// Arbitrary name/value pairs attached to the scope.
  ///
  /// Sentry.io docs do not talk about restrictions on the values, other than
  /// they must be JSON-serializable.
  final Map<String, dynamic> _extra = {};

  Map<String, dynamic> get extra => Map.unmodifiable(_extra);

  // TODO: EventProcessors, Contexts, BeforeBreadcrumbCallback, Breadcrumb Hint, clone

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
    _level = null;
    _transaction = null;
    _user = null;
    _fingerprint = null;
    _tags.clear();
    _extra.clear();
  }

  /// Sets a tag to the Scope
  void setTag(String key, String value) {
    assert(key != null, "Key can't be null");
    assert(value != null, "Key can't be null");

    _tags[key] = value;
  }

  /// Removes a tag from the Scope
  void removeTag(String key) {
    _tags.remove(key);
  }

  /// Sets an extra to the Scope
  void setExtra(String key, dynamic value) {
    assert(key != null, "Key can't be null");
    assert(value != null, "Value can't be null");

    _extra[key] = value;
  }

  /// Removes an extra from the Scope
  void removeExtra(String key) {
    _extra.remove(key);
  }
}
