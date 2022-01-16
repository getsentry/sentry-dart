import 'dart:async';
import 'dart:io';

import '../hub.dart';
import '../sentry.dart';
import '../sentry_options.dart';
import 'sentry_file.dart';

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

class SentryIoOverrides extends IOOverrides {
  final Hub _hub;
  final SentryOptions _options;

  SentryIoOverrides(this._hub, this._options);

  @override
  File createFile(String path) {
    return SentryFile(
      super.createFile(path),
      _hub,
      _options,
    );
  }
}
