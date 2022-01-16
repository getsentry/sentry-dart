import 'dart:io';
import '../hub.dart';
import '../sentry_options.dart';
import 'sentry_file.dart';

class SentryIoOverrides extends IOOverrides {
  final Hub _hub;
  final SentryOptions _options;

  SentryIoOverrides(this._hub, this._options);

  // Probably also interesting
  @override
  Directory createDirectory(String path) => super.createDirectory(path);

  @override
  File createFile(String path) {
    return SentryFile(
      super.createFile(path),
      _hub,
      _options,
    );
  }
}
