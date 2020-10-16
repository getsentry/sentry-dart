import 'dart:async';
import 'dart:collection';

import 'client.dart';
import 'protocol.dart';
import 'scope.dart';
import 'sentry_options.dart';

typedef ScopeCallback = void Function(Scope);

/// SDK API contract which combines a client and scope management
class Hub implements IHub {
  static SentryClient _getClient({SentryOptions fromOptions}) {
    return SentryClient(
      dsn: fromOptions.dsn,
      environmentAttributes: fromOptions.environmentAttributes,
      compressPayload: fromOptions.compressPayload,
      httpClient: fromOptions.httpClient,
      clock: fromOptions.clock,
      uuidGenerator: fromOptions.uuidGenerator,
    );
  }

  final ListQueue<_StackItem> _stack;

  final SentryOptions _options;

  factory Hub(SentryOptions options) {
    _validateOptions(options);

    return Hub._(options);
  }

  Hub._(SentryOptions options)
      : _options = options,
        _stack = ListQueue() {
    _stack.add(_StackItem(_getClient(fromOptions: options), Scope(_options)));
    _isEnabled = true;
  }

  static void _validateOptions(SentryOptions options) {
    if (options == null) {
      throw ArgumentError.notNull('options');
    }

    if (options.dsn == null) {
      throw ArgumentError.notNull('options.dsn');
    }
  }

  bool _isEnabled = false;

  @override
  bool get isEnabled => _isEnabled;

  SentryId _lastEventId;

  @override
  SentryId get lastEventId => _lastEventId;

  @override
  Future<SentryId> captureEvent(Event event) async {
    var sentryId = SentryId.empty();

    if (!_isEnabled) {
      _options.logger(
        SeverityLevel.warning,
        "Instance is disabled and this 'captureEvent' call is a no-op.",
      );
    } else if (event == null) {
      _options.logger(
        SeverityLevel.warning,
        'captureEvent called with null parameter.',
      );
    } else {
      final item = _stack.last;
      if (item != null) {
        try {
          sentryId = await item.client.captureEvent(event: event);
        } catch (err) {
          /* TODO add Event.id */
          _options.logger(
            SeverityLevel.error,
            'Error while capturing event with id: ${event}',
          );
        }
      } else {
        _options.logger(
          SeverityLevel.fatal,
          'Stack peek was null when captureEvent',
        );
      }
    }
    _lastEventId = sentryId;
    return sentryId;
  }

  @override
  Future<SentryId> captureException({
    dynamic throwable,
    dynamic stackTrace,
  }) async {
    var sentryId = SentryId.empty();

    if (!_isEnabled) {
      _options.logger(
        SeverityLevel.warning,
        "Instance is disabled and this 'captureException' call is a no-op.",
      );
    } else if (throwable == null) {
      _options.logger(
        SeverityLevel.warning,
        'captureException called with null parameter.',
      );
    } else {
      final item = _stack.last;
      if (item != null) {
        try {
          sentryId = await item.client.captureException(
            throwable,
            stackTrace: stackTrace,
          );
        } catch (err) {
          _options.logger(
            SeverityLevel.error,
            'Error while capturing exception : ${throwable}',
          );
        }
      } else {
        _options.logger(
          SeverityLevel.fatal,
          'Stack peek was null when captureException',
        );
      }
    }
    _lastEventId = sentryId;
    return sentryId;
  }

  @override
  Future<SentryId> captureMessage(
    Message message, {
    SeverityLevel level,
  }) async {
    var sentryId = SentryId.empty();

    if (!_isEnabled) {
      _options.logger(
        SeverityLevel.warning,
        "Instance is disabled and this 'captureMessage' call is a no-op.",
      );
    } else if (message == null) {
      _options.logger(
        SeverityLevel.warning,
        'captureMessage called with null parameter.',
      );
    } else {
      final item = _stack.last;
      if (item != null) {
        try {
          sentryId = await item.client.captureMessage(
            message: message,
            level: level,
          );
        } catch (err) {
          _options.logger(
            SeverityLevel.error,
            'Error while capturing message with id: ${message}',
          );
        }
      } else {
        _options.logger(
          SeverityLevel.fatal,
          'Stack peek was null when captureMessage',
        );
      }
    }
    _lastEventId = sentryId;
    return sentryId;
  }

  @override
  void bindClient(SentryClient client) {
    _stack.add(_StackItem(client, _stack.last.scope));
  }

  @override
  Hub clone() => Hub(_options)
    .._stack.addAll(_stack)
    .._lastEventId = _lastEventId
    .._isEnabled = _isEnabled;

  @override
  void close() {
    if (!_isEnabled) {
      _options.logger(
        SeverityLevel.warning,
        "Instance is disabled and this 'close' call is a no-op.",
      );
    } else {
      final item = _stack.last;
      if (item != null) {
        try {
          item.client.close();
        } catch (err) {
          _options.logger(
            SeverityLevel.error,
            'Error while closing the Hub.',
          );
        }
      } else {
        _options.logger(
          SeverityLevel.fatal,
          'Stack peek was NULL when closing Hub',
        );
      }
      _isEnabled = false;
    }
  }

  @override
  void configureScope(ScopeCallback callback) {
    // TODO: implement configureScope
    throw UnimplementedError();
  }

  @override
  void popScope() {
    // TODO: implement popScope
    throw UnimplementedError();
  }

  @override
  void pushScope() {
    // TODO: implement popScope
    throw UnimplementedError();
  }

  @override
  void withScope(ScopeCallback callback) {
    // TODO: implement withScope
    throw UnimplementedError();
  }
}

class _StackItem {
  final SentryClient client;

  final Scope scope;

  _StackItem(this.client, this.scope);
}

abstract class IHub {
  /// Check if the Hub is enabled/active.
  bool get isEnabled;

  /// Last event id recorded in the current scope
  SentryId get lastEventId;

  /// Captures the event.
  Future<SentryId> captureEvent(Event event);

  /// Captures the exception
  Future<SentryId> captureException({dynamic throwable, dynamic stackTrace});

  /// Captures the message.
  Future<SentryId> captureMessage(Message message, {SeverityLevel level});

  /// Flushes out the queue for up to timeout seconds and disable the Hub.
  void close();

  /// Runs the callback with a new scope which gets dropped at the end
  void pushScope();

  void popScope();

  /// Runs the callback with a new scope which gets dropped at the end
  void withScope(ScopeCallback callback);

  /// Configures the scope through the callback.
  void configureScope(ScopeCallback callback);

  /// Binds a different client to the hub
  void bindClient(SentryClient client);

  /// Flushes events queued up, but keeps the Hub enabled. Not implemented yet.
  /// void flush({int timeout} )

  /// Clones the Hub
  Hub clone();
}
