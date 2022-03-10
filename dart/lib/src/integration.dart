import 'dart:async';

import '../sentry.dart';

/// Code that provides middlewares, bindings or hooks into certain frameworks or environments,
/// along with code that inserts those bindings and activates them.
abstract class Integration<T extends SentryOptions> {

  /// A Callable method for the Integration interface
  FutureOr<void> call(Hub hub, T options);

  /// NoOp by default : only closeable integrations need to override
  FutureOr<void> close() {}
}
