import 'dart:async';
import 'dart:io';

import '../hub.dart';
import '../sentry.dart';
import 'sentry_file.dart';

FutureOr<void> runWithFileOverrides(AppRunner runner, Hub hub) {
  return IOOverrides.runWithIOOverrides(
    runner,
    SentryIoOverrides(hub),
  );
}

class SentryIoOverrides extends IOOverrides {
  final Hub _hub;

  SentryIoOverrides(this._hub);

  @override
  File createFile(String path) {
    return SentryFile(
      super.createFile(path),
      _hub,
    );
  }
}
