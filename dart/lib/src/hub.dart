import 'dart:async';
import 'dart:collection';

import 'client.dart';
import 'noop_client.dart';
import 'protocol.dart';
import 'scope.dart';
import 'sentry_options.dart';

typedef ScopeCallback = void Function(Scope);

/// SDK API contract which combines a client and scope management
class Hub {
  static SentryClient _getClient(SentryOptions options) {
    return SentryClient(options);
  }

  final ListQueue<_StackItem> _stack = ListQueue();

  /// if stack is empty, it throws IterableElementError.noElement()
  _StackItem _peek() => _stack.isNotEmpty ? _stack.first : null;

  final SentryOptions _options;

  factory Hub(SentryOptions options) {
    _validateOptions(options);

    return Hub._(options);
  }

  Hub._(SentryOptions options) : _options = options {
    _stack.add(_StackItem(_getClient(_options), Scope(_options)));
    _isEnabled = true;
  }

  static void _validateOptions(SentryOptions options) {
    if (options == null) {
      throw ArgumentError.notNull('SentryOptions is required.');
    }

    if (options.dsn?.isNotEmpty != true) {
      throw ArgumentError.notNull('DSN is required.');
    }
  }

  bool _isEnabled = false;

  /// Check if the Hub is enabled/active.
  bool get isEnabled => _isEnabled;

  SentryId _lastEventId = SentryId.empty();

  /// Last event id recorded by the Hub
  SentryId get lastEventId => _lastEventId;

  /// Captures the event.
  Future<SentryId> captureEvent(SentryEvent event, {dynamic hint}) async {
    var sentryId = SentryId.empty();

    if (!_isEnabled) {
      _options.logger(
        SentryLevel.warning,
        "Instance is disabled and this 'captureEvent' call is a no-op.",
      );
    } else if (event == null) {
      _options.logger(
        SentryLevel.warning,
        'captureEvent called with null parameter.',
      );
    } else {
      final item = _peek();
      if (item != null) {
        try {
          sentryId = await item.client.captureEvent(
            event,
            scope: item.scope,
            hint: hint,
          );
        } catch (err) {
          _options.logger(
            SentryLevel.error,
            'Error while capturing event with id: ${event.eventId.toString()}',
          );
        } finally {
          _lastEventId = sentryId;
        }
      } else {
        _options.logger(
          SentryLevel.fatal,
          'Stack peek was null when captureEvent',
        );
      }
    }
    return sentryId;
  }

  /// Captures the exception
  Future<SentryId> captureException(
    dynamic throwable, {
    dynamic stackTrace,
    dynamic hint,
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
      if (item != null) {
        try {
          sentryId = await item.client.captureException(
            throwable,
            stackTrace: stackTrace,
            scope: item.scope,
            hint: hint,
          );
        } catch (err) {
          _options.logger(
            SentryLevel.error,
            'Error while capturing exception : ${throwable}',
          );
        } finally {
          _lastEventId = sentryId;
        }
      } else {
        _options.logger(
          SentryLevel.fatal,
          'Stack peek was null when captureException',
        );
      }
    }

    return sentryId;
  }

  /// Captures the message.
  Future<SentryId> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
    String template,
    List<dynamic> params,
    dynamic hint,
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
      if (item != null) {
        try {
          sentryId = await item.client.captureMessage(
            message,
            level: level,
            template: template,
            params: params,
            scope: item.scope,
            hint: hint,
          );
        } catch (err) {
          _options.logger(
            SentryLevel.error,
            'Error while capturing message with id: ${message}',
          );
        } finally {
          _lastEventId = sentryId;
        }
      } else {
        _options.logger(
          SentryLevel.fatal,
          'Stack peek was null when captureMessage',
        );
      }
    }
    return sentryId;
  }

  /// Adds a breacrumb to the current Scope
  void addBreadcrumb(Breadcrumb crumb, {dynamic hint}) {
    if (!_isEnabled) {
      _options.logger(
        SentryLevel.warning,
        "Instance is disabled and this 'addBreadcrumb' call is a no-op.",
      );
    } else if (crumb == null) {
      _options.logger(
        SentryLevel.warning,
        'addBreadcrumb called with null parameter.',
      );
    } else {
      final item = _peek();
      if (item != null) {
        item.scope.addBreadcrumb(crumb, hint: hint);
      } else {
        _options.logger(
          SentryLevel.fatal,
          'Stack peek was null when addBreadcrumb',
        );
      }
    }
  }

  /// Binds a different client to the hub
  void bindClient(SentryClient client) {
    if (!_isEnabled) {
      _options.logger(SentryLevel.warning,
          "Instance is disabled and this 'bindClient' call is a no-op.");
    } else {
      final item = _peek();
      if (item != null) {
        if (client != null) {
          _options.logger(SentryLevel.debug, 'New client bound to scope.');
          item.client = client;
        } else {
          _options.logger(SentryLevel.debug, 'NoOp client bound to scope.');
          item.client = NoOpSentryClient();
        }
      } else {
        _options.logger(
          SentryLevel.fatal,
          'Stack peek was null when bindClient',
        );
      }
    }
  }

  /// Clones the Hub
  Hub clone() {
    if (!_isEnabled) {
      _options..logger(SentryLevel.warning, 'Disabled Hub cloned.');
    }
    final clone = Hub(_options);
    for (final item in _stack) {
      clone._stack.add(_StackItem(item.client, item.scope.clone()));
    }
    return clone;
  }

  /// Flushes out the queue for up to timeout seconds and disable the Hub.
  void close() {
    if (!_isEnabled) {
      _options.logger(
        SentryLevel.warning,
        "Instance is disabled and this 'close' call is a no-op.",
      );
    } else {
      final item = _peek();
      if (item != null) {
        try {
          item.client.close();
        } catch (err) {
          _options.logger(
            SentryLevel.error,
            'Error while closing the Hub.',
          );
        }
      } else {
        _options.logger(
          SentryLevel.fatal,
          'Stack peek was NULL when closing Hub',
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
      if (item != null) {
        try {
          callback(item.scope);
        } catch (err) {
          _options.logger(
            SentryLevel.error,
            "Error in the 'configureScope' callback.",
          );
        }
      } else {
        _options.logger(
          SentryLevel.fatal,
          'Stack peek was NULL when configureScope',
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
