import 'dart:async';

import 'package:sentry/sentry.dart';

class MockIntegration implements Integration {
  int closeCalls = 0;
  int callCalls = 0;

  @override
  FutureOr<void> call(Hub hub, SentryOptions options) async {
    callCalls = callCalls + 1;
  }

  @override
  void close() {
    closeCalls = closeCalls + 1;
  }
}
