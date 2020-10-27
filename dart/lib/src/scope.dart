import 'dart:collection';

import 'protocol.dart';
import 'sentry_options.dart';

/// Scope data to be sent with the event
class Scope {
  /// How important this event is.
  SentryLevel level;

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

  // TODO: Contexts

  /// Scope's event processor list
  final List<EventProcessor> _eventProcessors = [];

  List<EventProcessor> get eventProcessors =>
      List.unmodifiable(_eventProcessors);

  final SentryOptions _options;

  Scope(this._options) : assert(_options != null, 'SentryOptions is required');

  /// Adds a breadcrumb to the breadcrumbs queue
  void addBreadcrumb(Breadcrumb breadcrumb, {dynamic hint}) {
    assert(breadcrumb != null, "Breadcrumb can't be null");

    // bail out if maxBreadcrumbs is zero
    if (_options.maxBreadcrumbs == 0) {
      return;
    }

    // run before breadcrumb callback if set
    if (_options.beforeBreadcrumbCallback != null) {
      breadcrumb = _options.beforeBreadcrumbCallback(breadcrumb, hint);

      if (breadcrumb == null) {
        _options.logger(
            SentryLevel.info, 'Breadcrumb was dropped by beforeBreadcrumb');
        return;
      }
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

  /// Adds an event processor
  void addEventProcessor(EventProcessor eventProcessor) {
    assert(eventProcessor != null, "EventProcessor can't be null");

    _eventProcessors.add(eventProcessor);
  }

  /// Resets the Scope to its default state
  void clear() {
    clearBreadcrumbs();
    level = null;
    transaction = null;
    user = null;
    _fingerprint = null;
    _tags.clear();
    _extra.clear();
    _eventProcessors.clear();
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
  void removeExtra(String key) => _extra.remove(key);

  SentryEvent applyToEvent(SentryEvent event, dynamic hint) {
    if (event.transaction == null) {
      event = event.copyWith(transaction: transaction);
    }

    // set the user context if none is set.
    if (event.userContext == null) {
      event = event.copyWith(userContext: user);
    }

    // set the scope fingerprint if none is set.
    if (event.fingerprint == null) {
      event = event.copyWith(fingerprint: fingerprint);
    }

    // set the scope breadcrumbs if none is set.
    if (event.breadcrumbs == null) {
      event = event.copyWith(breadcrumbs: breadcrumbs);
    }

    // Merge the scope tags
    // if the scope and the event have tag entries with the same key,
    // the event tags will be kept
    event = event.copyWith(
      tags: tags.map((key, value) => MapEntry(key, value))
        ..addAll(event.tags ?? {}),
    );

    // Merge the scope extra.
    // if the scope and the event have extra entries with the same key,
    // the event extra will be keeped
    event = event.copyWith(
      extra: extra.map((key, value) => MapEntry(key, value))
        ..addAll(event.extra ?? {}),
    );

    // Merge the scope level.
    if (level != null) {
      event = event.copyWith(level: level);
    }

    for (final processor in _eventProcessors) {
      try {
        event = processor(event, hint);
      } catch (err) {
        _options.logger(
          SentryLevel.error,
          'An exception occurred while processing event by a processor : $err',
        );
      }
      if (event == null) {
        _options.logger(SentryLevel.debug, 'Event was dropped by a processor');
        break;
      }
    }

    return event;
  }

  /// Clones the current Scope
  Scope clone() {
    final clone = Scope(_options)
      ..user = user
      ..fingerprint = fingerprint != null ? List.from(fingerprint) : null
      ..transaction = transaction;

    for (final tag in _tags.keys) {
      clone.setTag(tag, _tags[tag]);
    }

    for (final extraKey in _extra.keys) {
      clone.setExtra(extraKey, _extra[extraKey]);
    }

    for (final breadcrumb in _breadcrumbs) {
      clone.addBreadcrumb(breadcrumb);
    }

    for (final eventProcessor in _eventProcessors) {
      clone.addEventProcessor(eventProcessor);
    }

    return clone;
  }
}
