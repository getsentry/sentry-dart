import 'dart:async';
import 'dart:collection';

import 'protocol.dart';
import 'scope.dart';
import 'sentry_client.dart';
import 'sentry_options.dart';

/// Configures the scope through the callback.
typedef ScopeCallback = void Function(Scope);

/// SDK API contract which combines a client and scope management
class Hub {
  static SentryClient _getClient(SentryOptions options) {
    return SentryClient(options);
  }

  final ListQueue<_StackItem> _stack = ListQueue();

  // peek can never return null since Stack can be created only with an item and
  // pop does not drop the last item.
  _StackItem _peek() => _stack.first;

  final SentryOptions _options;

  factory Hub(SentryOptions options) {
    _validateOptions(options);

    return Hub._(options);
  }

  Hub._(this._options) {
    _stack.add(_StackItem(_getClient(_options), Scope(_options)));
    _isEnabled = true;
  }

  static void _validateOptions(SentryOptions options) {
    if (options.dsn == null) {
      throw ArgumentError('DSN is required.');
    }
  }

  bool _isEnabled = false;

  /// Check if the Hub is enabled/active.
  bool get isEnabled => _isEnabled;

  SentryId _lastEventId = SentryId.empty();

  /// Last event id recorded by the Hub
  SentryId get lastEventId => _lastEventId;

  /// Captures the event.
  Future<SentryId> captureEvent(
    SentryEvent event, {
    dynamic stackTrace,
    dynamic hint,
    ScopeCallback? withScope,
  }) async {
    var sentryId = SentryId.empty();

    if (!_isEnabled) {
      _options.logger(
        SentryLevel.warning,
        "Instance is disabled and this 'captureEvent' call is a no-op.",
      );
    } else {
      final item = _peek();
      final scope = _cloneAndRunWithScope(item.scope, withScope);

      try {
        sentryId = await item.client.captureEvent(
          event,
          stackTrace: stackTrace,
          scope: scope,
          hint: hint,
        );
      } catch (exception, stackTrace) {
        _options.logger(
          SentryLevel.error,
          'Error while capturing event with id: ${event.eventId}',
          error: exception,
          stackTrace: stackTrace,
        );
      } finally {
        _lastEventId = sentryId;
      }
    }
    return sentryId;
  }

  /// Captures the exception
  Future<SentryId> captureException(
    dynamic throwable, {
    dynamic stackTrace,
    dynamic hint,
    ScopeCallback? withScope,
  }) async {
    var sentryId = SentryId.empty();

    if (!_isEnabled) {
      _options.logger(
        SentryLevel.warning,
        "Instance is disabled and this 'captureException' call is a no-op.",
      );
    } else if (throwable == null) {
      _options.logger(
        SentryLevel.warning,
        'captureException called with null parameter.',
      );
    } else {
      final item = _peek();
      final scope = _cloneAndRunWithScope(item.scope, withScope);

      try {
        sentryId = await item.client.captureException(
          throwable,
          stackTrace: stackTrace,
          scope: scope,
          hint: hint,
        );
      } catch (exception, stackTrace) {
        _options.logger(
          SentryLevel.error,
          'Error while capturing exception',
          error: exception,
          stackTrace: stackTrace,
        );
      } finally {
        _lastEventId = sentryId;
      }
    }

    return sentryId;
  }

  /// Captures the message.
  Future<SentryId> captureMessage(
    String? message, {
    SentryLevel? level,
    String? template,
    List<dynamic>? params,
    dynamic hint,
    ScopeCallback? withScope,
  }) async {
    var sentryId = SentryId.empty();

    if (!_isEnabled) {
      _options.logger(
        SentryLevel.warning,
        "Instance is disabled and this 'captureMessage' call is a no-op.",
      );
    } else if (message == null) {
      _options.logger(
        SentryLevel.warning,
        'captureMessage called with null parameter.',
      );
    } else {
      final item = _peek();
      final scope = _cloneAndRunWithScope(item.scope, withScope);

      try {
        sentryId = await item.client.captureMessage(
          message,
          level: level,
          template: template,
          params: params,
          scope: scope,
          hint: hint,
        );
      } catch (exception, stackTrace) {
        _options.logger(
          SentryLevel.error,
          'Error while capturing message with id: $message',
          error: exception,
          stackTrace: stackTrace,
        );
      } finally {
        _lastEventId = sentryId;
      }
    }
    return sentryId;
  }

  Scope _cloneAndRunWithScope(Scope scope, ScopeCallback? withScope) {
    if (withScope != null) {
      scope = scope.clone();
      withScope(scope);
    }
    return scope;
  }

  /// Adds a breacrumb to the current Scope
  void addBreadcrumb(Breadcrumb crumb, {dynamic hint}) {
    if (!_isEnabled) {
      _options.logger(
        SentryLevel.warning,
        "Instance is disabled and this 'addBreadcrumb' call is a no-op.",
      );
    } else {
      final item = _peek();
      item.scope.addBreadcrumb(crumb, hint: hint);
    }
  }

  /// Binds a different client to the hub
  void bindClient(SentryClient client) {
    if (!_isEnabled) {
      _options.logger(
        SentryLevel.warning,
        "Instance is disabled and this 'bindClient' call is a no-op.",
      );
    } else {
      final item = _peek();
      _options.logger(SentryLevel.debug, 'New client bound to scope.');
      item.client = client;
    }
  }

  /// Clones the Hub
  Hub clone() {
    if (!_isEnabled) {
      _options.logger(SentryLevel.warning, 'Disabled Hub cloned.');
    }
    final clone = Hub(_options);
    for (final item in _stack) {
      clone._stack.add(_StackItem(item.client, item.scope.clone()));
    }
    return clone;
  }

  /// Flushes out the queue for up to timeout seconds and disable the Hub.
  Future<void> close() async {
    if (!_isEnabled) {
      _options.logger(
        SentryLevel.warning,
        "Instance is disabled and this 'close' call is a no-op.",
      );
    } else {
      // close integrations
      for (final integration in _options.integrations) {
        await integration.close();
      }

      final item = _peek();

      try {
        item.client.close();
      } catch (exception, stackTrace) {
        _options.logger(
          SentryLevel.error,
          'Error while closing the Hub',
          error: exception,
          stackTrace: stackTrace,
        );
      }

      _isEnabled = false;
    }
  }

  /// Configures the scope through the callback.
  void configureScope(ScopeCallback callback) {
    if (!_isEnabled) {
      _options.logger(
        SentryLevel.warning,
        "Instance is disabled and this 'configureScope' call is a no-op.",
      );
    } else {
      final item = _peek();

      try {
        callback(item.scope);
      } catch (err) {
        _options.logger(
          SentryLevel.error,
          "Error in the 'configureScope' callback, error: $err",
        );
      }
    }
  }
}

class _StackItem {
  SentryClient client;

  final Scope scope;

  _StackItem(this.client, this.scope);
}
