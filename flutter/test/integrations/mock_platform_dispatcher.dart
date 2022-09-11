import 'dart:ui';

import 'package:sentry_flutter/src/integrations/on_error_integration.dart';

class MockPlatformDispatcher implements PlatformDispatcher {
  ErrorCallback? onErrorHandler;

  @override
  // ignore: override_on_non_overriding_member
  ErrorCallback? get onError => onErrorHandler;

  @override
  // ignore: override_on_non_overriding_member
  set onError(ErrorCallback? onError) {
    onErrorHandler = onError;
  }

  @override
  void noSuchMethod(Invocation invocation) {}
}
