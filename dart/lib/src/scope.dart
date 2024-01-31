import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';

import 'event_processor.dart';
import 'hint.dart';
import 'propagation_context.dart';
import 'protocol.dart';
import 'scope_observer.dart';
import 'sentry_attachment/sentry_attachment.dart';
import 'sentry_options.dart';
import 'sentry_span_interface.dart';
import 'sentry_tracer.dart';

typedef _OnScopeObserver = Future<void> Function(ScopeObserver observer);

/// Scope data to be sent with the event
class Scope {
  /// How important this event is.
  SentryLevel? level;

  String? _transaction;

  /// The name of the transaction which generated this event,
  /// for example, the route name: `"/users/<username>/"`.
  String? get transaction {
    return ((span is SentryTracer) ? (span as SentryTracer?)?.name : null) ??
        _transaction;
  }

  set transaction(String? transaction) {
    _transaction = transaction;

    if (_transaction != null && span != null) {
      final currentTransaction =
          (span is SentryTracer) ? (span as SentryTracer?) : null;
      currentTransaction?.name = _transaction!;
    }
  }

  /// Returns active transaction or null if there is no active transaction.
  ISentrySpan? span;

  @internal
  PropagationContext propagationContext = PropagationContext();

  SentryUser? _user;

  /// Get the current user.
  SentryUser? get user => _user;

  void _setUserSync(SentryUser? user) {
    _user = user;
  }

  /// Set the current user.
  Future<void> setUser(SentryUser? user) async {
    _setUserSync(user);
    await _callScopeObservers(
        (scopeObserver) async => await scopeObserver.setUser(user));
  }

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

  void _setContextsSync(String key, dynamic value) {
    // if it's a List, it should not be a List<SentryRuntime> because it can't
    // be wrapped by the value object since it's a special property for having
    // multiple runtimes and it has a dedicated property within the Contexts class.
    _contexts[key] = (value is num ||
            value is bool ||
            value is String ||
            (value is List &&
                (value is! List<SentryRuntime> &&
                    key != SentryRuntime.listType)))
        ? {'value': value}
        : value;
  }

  /// add an entry to the Scope's contexts
  Future<void> setContexts(String key, dynamic value) async {
    _setContextsSync(key, value);
    await _callScopeObservers(
        (scopeObserver) async => await scopeObserver.setContexts(key, value));
  }

  /// Removes a value from the Scope's contexts
  Future<void> removeContexts(String key) async {
    _contexts.remove(key);

    await _callScopeObservers(
        (scopeObserver) async => await scopeObserver.removeContexts(key));
  }

  /// Scope's event processor list
  ///
  /// Scope's event processors are executed before the global Event processors
  final List<EventProcessor> _eventProcessors = [];

  List<EventProcessor> get eventProcessors =>
      List.unmodifiable(_eventProcessors);

  final SentryOptions _options;
  bool _enableScopeSync = true;

  final List<SentryAttachment> _attachments = [];

  List<SentryAttachment> get attachments => List.unmodifiable(_attachments);

  Scope(this._options);

  Breadcrumb? _addBreadCrumbSync(Breadcrumb breadcrumb, Hint hint) {
    // bail out if maxBreadcrumbs is zero
    if (_options.maxBreadcrumbs == 0) {
      return null;
    }

    Breadcrumb? processedBreadcrumb = breadcrumb;
    // run before breadcrumb callback if set
    if (_options.beforeBreadcrumb != null) {
      try {
        processedBreadcrumb = _options.beforeBreadcrumb!(
          processedBreadcrumb,
          hint,
        );
        if (processedBreadcrumb == null) {
          _options.logger(
            SentryLevel.info,
            'Breadcrumb was dropped by beforeBreadcrumb',
          );
          return null;
        }
      } catch (exception, stackTrace) {
        _options.logger(
          SentryLevel.error,
          'The BeforeBreadcrumb callback threw an exception',
          exception: exception,
          stackTrace: stackTrace,
        );
        if (_options.automatedTestMode) {
          rethrow;
        }
      }
    }
    if (processedBreadcrumb != null) {
      // remove first item if list is full
      if (_breadcrumbs.length >= _options.maxBreadcrumbs &&
          _breadcrumbs.isNotEmpty) {
        _breadcrumbs.removeFirst();
      }
      _breadcrumbs.add(processedBreadcrumb);
    }
    return processedBreadcrumb;
  }

  /// Adds a breadcrumb to the breadcrumbs queue
  Future<void> addBreadcrumb(Breadcrumb breadcrumb, {Hint? hint}) async {
    final addedBreadcrumb = _addBreadCrumbSync(breadcrumb, hint ?? Hint());
    if (addedBreadcrumb != null) {
      await _callScopeObservers((scopeObserver) async =>
          await scopeObserver.addBreadcrumb(addedBreadcrumb));
    }
  }

  void addAttachment(SentryAttachment attachment) {
    _attachments.add(attachment);
  }

  void clearAttachments() {
    _attachments.clear();
  }

  void _clearBreadcrumbsSync() {
    _breadcrumbs.clear();
  }

  /// Clear all the breadcrumbs
  Future<void> clearBreadcrumbs() async {
    _clearBreadcrumbsSync();
    await _callScopeObservers(
        (scopeObserver) async => await scopeObserver.clearBreadcrumbs());
  }

  /// Adds an event processor
  void addEventProcessor(EventProcessor eventProcessor) {
    _eventProcessors.add(eventProcessor);
  }

  /// Resets the Scope to its default state
  Future<void> clear() async {
    clearAttachments();
    level = null;
    span = null;
    _transaction = null;
    _fingerprint = [];
    _tags.clear();
    _extra.clear();
    _eventProcessors.clear();

    _clearBreadcrumbsSync();
    _setUserSync(null);

    await clearBreadcrumbs();
    await setUser(null);
  }

  void _setTagSync(String key, String value) {
    _tags[key] = value;
  }

  /// Sets a tag to the Scope
  Future<void> setTag(String key, String value) async {
    _setTagSync(key, value);
    await _callScopeObservers(
        (scopeObserver) async => await scopeObserver.setTag(key, value));
  }

  /// Removes a tag from the Scope
  Future<void> removeTag(String key) async {
    _tags.remove(key);
    await _callScopeObservers(
        (scopeObserver) async => await scopeObserver.removeTag(key));
  }

  void _setExtraSync(String key, dynamic value) {
    _extra[key] = value;
  }

  /// Sets an extra to the Scope
  Future<void> setExtra(String key, dynamic value) async {
    _setExtraSync(key, value);
    await _callScopeObservers(
        (scopeObserver) async => await scopeObserver.setExtra(key, value));
  }

  /// Removes an extra from the Scope
  Future<void> removeExtra(String key) async {
    _extra.remove(key);
    await _callScopeObservers(
        (scopeObserver) async => await scopeObserver.removeExtra(key));
  }

  Future<SentryEvent?> applyToEvent(
    SentryEvent event,
    Hint hint,
  ) async {
    event = event.copyWith(
      transaction: event.transaction ?? transaction,
      user: _mergeUsers(user, event.user),
      breadcrumbs: (event.breadcrumbs?.isNotEmpty ?? false)
          ? event.breadcrumbs
          : List.from(_breadcrumbs),
      tags: tags.isNotEmpty ? _mergeEventTags(event) : event.tags,
      // ignore: deprecated_member_use_from_same_package
      extra: extra.isNotEmpty ? _mergeEventExtra(event) : event.extra,
    );

    if (event is! SentryTransaction) {
      event = event.copyWith(
          fingerprint: (event.fingerprint?.isNotEmpty ?? false)
              ? event.fingerprint
              : _fingerprint,
          level: level ?? event.level);
    }

    _contexts.clone().forEach((key, value) {
      // add the contexts runtime list to the event.contexts.runtimes
      if (key == SentryRuntime.listType &&
          value is List<SentryRuntime> &&
          value.isNotEmpty) {
        _mergeEventContextsRuntimes(value, event);
      } else if (key != SentryRuntime.listType &&
          (!event.contexts.containsKey(key) || event.contexts[key] == null) &&
          value != null) {
        event.contexts[key] = value;
      }
    });

    final newSpan = span;
    if (event.contexts.trace == null) {
      if (newSpan != null) {
        event.contexts.trace = newSpan.context.toTraceContext(
          sampled: newSpan.samplingDecision?.sampled,
        );
      } else {
        event.contexts.trace =
            SentryTraceContext.fromPropagationContext(propagationContext);
      }
    }

    SentryEvent? processedEvent = event;
    for (final processor in _eventProcessors) {
      try {
        final e = processor.apply(processedEvent!, hint);
        if (e is Future<SentryEvent?>) {
          processedEvent = await e;
        } else {
          processedEvent = e;
        }
      } catch (exception, stackTrace) {
        _options.logger(
          SentryLevel.error,
          'An exception occurred while processing event by a processor',
          exception: exception,
          stackTrace: stackTrace,
        );
        if (_options.automatedTestMode) {
          rethrow;
        }
      }
      if (processedEvent == null) {
        _options.logger(SentryLevel.debug, 'Event was dropped by a processor');
        break;
      }
    }

    return processedEvent;
  }

  /// Merge the scope contexts runtimes and the event contexts runtimes.
  void _mergeEventContextsRuntimes(
      List<SentryRuntime> values, SentryEvent event) {
    for (final runtime in values) {
      event.contexts.addRuntime(runtime);
    }
  }

  /// If the scope and the event have tag entries with the same key,
  /// the event tags will be kept.
  Map<String, String> _mergeEventTags(SentryEvent event) =>
      tags.map((key, value) => MapEntry(key, value))..addAll(event.tags ?? {});

  /// If the scope and the event have extra entries with the same key,
  /// the event extra will be kept.
  Map<String, dynamic> _mergeEventExtra(SentryEvent event) =>
      extra.map((key, value) => MapEntry(key, value))
        // ignore: deprecated_member_use_from_same_package
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
      data: _mergeUserData(eventUser?.data, scopeUser.data),
      // ignore: deprecated_member_use_from_same_package
      extras: _mergeUserData(eventUser?.extras, scopeUser.extras),
    );
  }

  /// If the User on the scope and the user of an event have extra entries with
  /// the same key, the event user extra will be kept.
  Map<String, dynamic> _mergeUserData(
    Map<String, dynamic>? eventData,
    Map<String, dynamic>? scopeData,
  ) {
    final map = <String, dynamic>{};
    if (eventData != null) {
      map.addAll(eventData);
    }
    if (scopeData == null) {
      return map;
    }
    for (var value in scopeData.entries) {
      map.putIfAbsent(value.key, () => value.value);
    }
    return map;
  }

  /// Clones the current Scope
  Scope clone() {
    final clone = Scope(_options)
      ..level = level
      ..fingerprint = List.from(fingerprint)
      .._transaction = _transaction
      ..span = span
      .._enableScopeSync = false;

    clone._setUserSync(user);

    final tags = List.from(_tags.keys);
    for (final tag in tags) {
      final value = _tags[tag];
      if (value != null) {
        clone._setTagSync(tag, value);
      }
    }

    for (final extraKey in List.from(_extra.keys)) {
      clone._setExtraSync(extraKey, _extra[extraKey]);
    }

    for (final breadcrumb in List.from(_breadcrumbs)) {
      clone._addBreadCrumbSync(breadcrumb, Hint());
    }

    for (final eventProcessor in List.from(_eventProcessors)) {
      clone.addEventProcessor(eventProcessor);
    }

    for (final entry in Map.from(contexts).entries) {
      if (entry.value != null) {
        clone._setContextsSync(entry.key, entry.value);
      }
    }

    for (final attachment in List.from(_attachments)) {
      clone.addAttachment(attachment);
    }

    return clone;
  }

  Future<void> _callScopeObservers(_OnScopeObserver action) async {
    if (_options.enableScopeSync && _enableScopeSync) {
      for (final scopeObserver in _options.scopeObservers) {
        await action(scopeObserver);
      }
    }
  }
}
