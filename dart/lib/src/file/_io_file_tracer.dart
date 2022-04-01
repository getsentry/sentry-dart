import 'dart:async';
import 'dart:io';

import '../hub.dart';
import '../sentry.dart';
import '../sentry_options.dart';
import 'sentry_io_overrides.dart';

FutureOr<void> runWithFileOverrides(
  AppRunner runner,
  Hub hub,
  SentryOptions options,
) {
  return IOOverrides.runWithIOOverrides(
    runner,
    SentryIoOverrides(hub, options),
  );
}
