import 'dart:io';
import 'package:sentry/sentry.dart';

import '../sentry_file.dart';

/// If set to [IOOverrides.global], newly created [File] instances will be of
/// type [SentryFile].
/// Enable by adding [SentryIOOverridesIntegration] to [SentryOptions].
class SentryIOOverrides extends IOOverrides {
  final Hub _hub;

  SentryIOOverrides(this._hub);

  @override
  File createFile(String path) {
    return SentryFile(
      super.createFile(path),
      hub: _hub,
    );
  }
}
