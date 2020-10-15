import 'dart:collection';

import 'package:meta/meta.dart';

import 'client.dart';
import 'protocol.dart';
import 'scope.dart';
import 'sentry_options.dart';

/// SDK API contract which combines a client and scope management
class Hub implements HubInterface {
  static SentryClient _getClient({SentryOptions fromOptions}) => SentryClient(
        dsn: fromOptions.dsn,
        environmentAttributes: fromOptions.environmentAttributes,
        compressPayload: fromOptions.compressPayload,
        httpClient: fromOptions.httpClient,
        clock: fromOptions.clock,
        uuidGenerator: fromOptions.uuidGenerator,
      );

  final ListQueue<_StackItem> _stack;

  factory Hub(SentryOptions options) {
    _validateOptions(options);

    final client = _getClient(fromOptions: options);
    return Hub._(client: client, scope: Scope(options));
  }

  Hub._({@required SentryClient client, @required Scope scope})
      : _stack = ListQueue() {
    _stack.add(_StackItem(client, scope));
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
  SentryId captureEvent(Event event) {
    // TODO: implement captureEvent
    throw UnimplementedError();
  }

  @override
  SentryId captureException({Message message, SeverityLevel level}) {
    // TODO: implement captureException
    throw UnimplementedError();
  }

  @override
  SentryId captureMessage({Message message, SeverityLevel level}) {
    // TODO: implement captureMessage
    throw UnimplementedError();
  }

  @override
  void addBreadcrumb(Breadcrumb breadCrumb) {
    // TODO: implement addBreadcrumb
    throw UnimplementedError();
  }

  @override
  void bindClient(SentryClient client) {
    // TODO: implement bindClient
    throw UnimplementedError();
  }

  @override
  void clearBreadcrumbs() {
    // TODO: implement clearBreadcrumbs
    throw UnimplementedError();
  }

  @override
  Hub clone() {
    // TODO: implement clone
    throw UnimplementedError();
  }

  @override
  void close() {
    // TODO: implement close
    throw UnimplementedError();
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
    // TODO: implement pushScope
    throw UnimplementedError();
  }

  @override
  void removeExtra(String key) {
    // TODO: implement removeExtra
    throw UnimplementedError();
  }

  @override
  void removeTag({String key}) {
    // TODO: implement removeTag
    throw UnimplementedError();
  }

  @override
  void setExtra(String key, String value) {
    // TODO: implement setExtra
    throw UnimplementedError();
  }

  @override
  void setFingerPrint(List<String> fingerPrint) {
    // TODO: implement setFingerPrint
    throw UnimplementedError();
  }

  @override
  void setLevel(SeverityLevel level) {
    // TODO: implement setLevel
    throw UnimplementedError();
  }

  @override
  void setTag({String key, String value}) {
    // TODO: implement setTag
    throw UnimplementedError();
  }

  @override
  void setTransaction(String transaction) {
    // TODO: implement setTransaction
    throw UnimplementedError();
  }

  @override
  void setUser(User user) {
    // TODO: implement setUser
    throw UnimplementedError();
  }

  @override
  void startSession() {
    // TODO: implement startSession
    throw UnimplementedError();
  }

  @override
  void stopSession() {
    // TODO: implement stopSession
    throw UnimplementedError();
  }

  @override
  void withScope(ScopeCallback callback) {
    // TODO: implement withScope
    throw UnimplementedError();
  }
}

class _StackItem {
  final SentryClient _client;

  final Scope _scope;

  _StackItem(this._client, this._scope);
}

abstract class HubInterface {
  /// Check if the Hub is enabled/active.
  bool get isEnabled;

  /// Last event id recorded in the current scope
  SentryId get lastEventId;

  /// Captures the event.
  SentryId captureEvent(Event event);

  /// Captures the exception
  SentryId captureException({Message message, SeverityLevel level});

  /// Captures the message.
  SentryId captureMessage({Message message, SeverityLevel level});

  /// Starts a new session. If there's a running session, it ends it before starting the new one.
  void startSession();

  /// ends the current session
  void stopSession();

  /// Flushes out the queue for up to timeout seconds and disable the Hub.
  void close();

  /// Adds a breadcrumb to the current Scope
  void addBreadcrumb(Breadcrumb breadCrumb);

  /// Sets the level of all events sent within current Scope
  void setLevel(SeverityLevel level);

  /// Sets the name of the current transaction to the current Scope.
  void setTransaction(String transaction);

  /// Shallow merges user configuration (email, username, etc) to the current Scope.
  void setUser(User user);

  /// Sets the fingerprint to group specific events together to the current Scope.
  void setFingerPrint(List<String> fingerPrint);

  /// Deletes current breadcrumbs from the current scope.
  void clearBreadcrumbs();

  /// Sets the tag to a string value to the current Scope, overwriting a potential previous value
  void setTag({String key, String value});

  /// Removes the tag to a string value to the current Scope
  void removeTag({String key});

  /// Sets the extra key to an arbitrary value to the current Scope, overwriting a potential previous value
  void setExtra(String key, String value);

  /// Removes the extra key to an arbitrary value to the current Scope
  void removeExtra(String key);

  /// Pushes a new scope while inheriting the current scope's data.
  void pushScope();

  /// Removes the first scope
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

typedef ScopeCallback = void Function(Scope);
