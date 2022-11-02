import 'dart:io';
import 'dart:async';

import 'package:sentry/plugin/plugin.dart';

/// Main class that executes the SentryDartPlugin
Future<void> main(List<String> arguments) async {
  exitCode = await SentryDartPlugin().run(arguments);
}
