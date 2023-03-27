
import 'dart:io';
import 'package:sentry/sentry.dart';

import 'sentry_file.dart';

class SentryIoOverrides extends IOOverrides {
  final Hub _hub;
  final SentryOptions _options;

  SentryIoOverrides(this._hub, this._options);

  @override
  File createFile(String path) {
    if (_options.platformChecker.isWeb || !_options.isTracingEnabled()) {
      return super.createFile(path);
    }
    return SentryFile(
      super.createFile(path),
      hub: _hub,
    );
  }
}
