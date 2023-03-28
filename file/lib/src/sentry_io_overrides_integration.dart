import 'dart:async';
import 'dart:io';

import 'package:sentry/sentry.dart';
import 'sentry_io_overrides.dart';

class SentryIOOverridesIntegration extends Integration<SentryOptions> {
  IOOverrides? _previousOverrides;

  @override
  FutureOr<void> call(Hub hub, SentryOptions options) {
    _previousOverrides = IOOverrides.current;
    if (options.isTracingEnabled()) {
      IOOverrides.global = SentryIOOverrides(hub);
      options.sdk.addIntegration('sentryIOOverridesIntegration');
    }
  }

  @override
  FutureOr<void> close() {
    IOOverrides.global = _previousOverrides;
  }
}
