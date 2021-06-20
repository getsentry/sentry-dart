import 'dart:collection';

import 'event_processor.dart';
import 'protocol.dart';
import 'sentry_options.dart';

/// Scope data to be sent with the event
class Scope {
  /// How important this event is.
  SentryLevel? level;

  /// The name of the transaction which generated this event,
  /// for example, the route name: `"/users/<username>/"`.
  String? transaction;

  /// Information about the current user.
  SentryUser? user;

  List<String> _fingerprint = [];

  /// Used to deduplicate events by grouping ones with the same fingerprint
  /// together.
  ///
  /// Example:
  ///
  ///     // A completely custom fingerprint:
  ///     var custom = ['foo', 'bar', 'baz'];
  List<String> get fingerprint => List.unmodifiable(_fingerprint);

  set fingerprint(List<String> fingerprint) {
    _fingerprint = List.from(fingerprint);
  }

  /// List of breadcrumbs for this scope.
  final Queue<Breadcrumb> _breadcrumbs = Queue();

  /// Unmodifiable List of breadcrumbs
  /// See also:
  /// * https://docs.sentry.io/enriching-error-data/breadcrumbs/?platform=javascript
  List<Breadcrumb> get breadcrumbs => List.unmodifiable(_breadcrumbs);

  final Map<String, String> _tags = {};

  /// Name/value pairs that events can be searched by.
  Map<String, String> get tags => Map.unmodifiable(_tags);

  final Map<String, dynamic> _extra = {};

  /// Arbitrary name/value pairs attached to the scope.
  ///
  /// Sentry.io docs do not talk about restrictions on the values, other than
  /// they must be JSON-serializable.
  Map<String, dynamic> get extra => Map.unmodifiable(_extra);

  final Contexts _contexts = Contexts();

  /// Unmodifiable map of the scope contexts key/value
  /// See also:
  /// * https://docs.sentry.io/platforms/java/enriching-events/context/
  Map<String, dynamic> get contexts => Map.unmodifiable(_contexts);

  /// add an entry to the Scope's contexts
  void setContexts(String key, dynamic value) {
    _contexts[key] = (value is num || value is bool || value is String)
        ? {'value': value}
        : value;
  }

  /// Removes a value from the Scope's contexts
  void removeContexts(String key) {
    _contexts.remove(key);
  }

  /// Scope's event processor list
  ///
  /// Scope's event processors are executed before the global Event processors
  final List<EventProcessor> _eventProcessors = [];

  List<EventProcessor> get eventProcessors =>
      List.unmodifiable(_eventProcessors);

  final SentryOptions _options;

  Scope(this._options);

  /// Adds a breadcrumb to the breadcrumbs queue
  void addBreadcrumb(Breadcrumb breadcrumb, {dynamic hint}) {
    // bail out if maxBreadcrumbs is zero
    if (_options.maxBreadcrumbs == 0) {
      return;
    }

    Breadcrumb? processedBreadcrumb = breadcrumb;
    // run before breadcrumb callback if set
    if (_options.beforeBreadcrumb != null) {
      processedBreadcrumb = _options.beforeBreadcrumb!(
        processedBreadcrumb,
        hint: hint,
      );

      if (processedBreadcrumb == null) {
        _options.logger(
          SentryLevel.info,
          'Breadcrumb was dropped by beforeBreadcrumb',
        );
        return;
      }
    }

    // remove first item if list is full
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
    _eventProcessors.add(eventProcessor);
  }

  /// Resets the Scope to its default state
  void clear() {
    clearBreadcrumbs();
    level = null;
    transaction = null;
    user = null;
    _fingerprint = [];
    _tags.clear();
    _extra.clear();
    _eventProcessors.clear();
  }

  /// Sets a tag to the Scope
  void setTag(String key, String value) {
    _tags[key] = value;
  }

  /// Removes a tag from the Scope
  void removeTag(String key) {
    _tags.remove(key);
  }

  /// Sets an extra to the Scope
  void setExtra(String key, dynamic value) {
    _extra[key] = value;
  }

  /// Removes an extra from the Scope
  void removeExtra(String key) => _extra.remove(key);

  Future<SentryEvent?> applyToEvent(SentryEvent event, dynamic hint) async {
    event = event.copyWith(
      transaction: event.transaction ?? transaction,
      user: _mergeUsers(user, event.user),
      fingerprint: (event.fingerprint?.isNotEmpty ?? false)
          ? event.fingerprint
          : _fingerprint,
      breadcrumbs: (event.breadcrumbs?.isNotEmpty ?? false)
          ? event.breadcrumbs
          : List.from(_breadcrumbs),
      tags: tags.isNotEmpty ? _mergeEventTags(event) : event.tags,
      extra: extra.isNotEmpty ? _mergeEventExtra(event) : event.extra,
      level: level ?? event.level,
    );

    _contexts.clone().forEach((key, value) {
      // add the contexts runtime list to the event.contexts.runtimes
      if (key == SentryRuntime.listType && value is List && value.isNotEmpty) {
        _mergeEventContextsRuntimes(value, event);
      } else if (key != SentryRuntime.listType &&
          (!event.contexts.containsKey(key) || event.contexts[key] == null) &&
          value != null) {
        event.contexts[key] = value;
      }
    });

    SentryEvent? processedEvent = event;
    for (final processor in _eventProcessors) {
      try {
        processedEvent = await processor.apply(processedEvent!, hint: hint);
      } catch (exception, stackTrace) {
        _options.logger(
          SentryLevel.error,
          'An exception occurred while processing event by a processor',
          error: exception,
          stackTrace: stackTrace,
        );
      }
      if (processedEvent == null) {
        _options.logger(SentryLevel.debug, 'Event was dropped by a processor');
        break;
      }
    }

    return processedEvent;
  }

  /// Merge the scope contexts runtimes and the event contexts runtimes.
  void _mergeEventContextsRuntimes(List value, SentryEvent event) =>
      value.forEach((runtime) => event.contexts.addRuntime(runtime));

  /// If the scope and the event have tag entries with the same key,
  /// the event tags will be kept.
  Map<String, String> _mergeEventTags(SentryEvent event) =>
      tags.map((key, value) => MapEntry(key, value))..addAll(event.tags ?? {});

  /// If the scope and the event have extra entries with the same key,
  /// the event extra will be kept.
  Map<String, dynamic> _mergeEventExtra(SentryEvent event) =>
      extra.map((key, value) => MapEntry(key, value))
        ..addAll(event.extra ?? {});

  /// If scope and event have a user, the user of the event takes
  /// precedence.
  SentryUser? _mergeUsers(SentryUser? scopeUser, SentryUser? eventUser) {
    if (scopeUser == null && eventUser != null) {
      return eventUser;
    }
    if (eventUser == null && scopeUser != null) {
      return scopeUser;
    }
    // otherwise the user of scope takes precedence over the event user
    return scopeUser?.copyWith(
      id: eventUser?.id,
      email: eventUser?.email,
      ipAddress: eventUser?.ipAddress,
      username: eventUser?.username,
      extras: _mergeUserExtra(eventUser?.extras, scopeUser.extras),
    );
  }

  /// If the User on the scope and the user of an event have extra entries with
  /// the same key, the event user extra will be kept.
  Map<String, dynamic> _mergeUserExtra(
    Map<String, dynamic>? eventExtra,
    Map<String, dynamic>? scopeExtra,
  ) {
    final map = <String, dynamic>{};
    if (eventExtra != null) {
      map.addAll(eventExtra);
    }
    if (scopeExtra == null) {
      return map;
    }
    for (var value in scopeExtra.entries) {
      map.putIfAbsent(value.key, () => value.value);
    }
    return map;
  }

  /// Clones the current Scope
  Scope clone() {
    final clone = Scope(_options)
      ..user = user
      ..fingerprint = List.from(fingerprint)
      ..transaction = transaction;

    for (final tag in _tags.keys) {
      clone.setTag(tag, _tags[tag]!);
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

    contexts.forEach((key, value) {
      if (value != null) {
        clone.setContexts(key, value);
      }
    });

    return clone;
  }
}
