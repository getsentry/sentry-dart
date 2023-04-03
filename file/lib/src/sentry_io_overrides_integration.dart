import 'dart:async';
import 'dart:io';

import 'package:sentry/sentry.dart';
import 'sentry_io_overrides.dart';

/// When installed, every new file will be created as [SentryFile].
/// When installed, operations will use [SentryFile] instead of dart:io's [File]
/// implementation whenever [File] is used.
class SentryIOOverridesIntegration extends Integration<SentryOptions> {
  IOOverrides? _previousOverrides;
  bool _installed = false;

  @override
  FutureOr<void> call(Hub hub, SentryOptions options) {
    if (options.isTracingEnabled()) {
      _previousOverrides = IOOverrides.current;
      _installed = true;
      IOOverrides.global = SentryIOOverrides(hub);
      options.sdk.addIntegration('sentryIOOverridesIntegration');
    }
  }

  @override
  FutureOr<void> close() {
    if (_installed) {
      IOOverrides.global = _previousOverrides;
    }
  }
}
