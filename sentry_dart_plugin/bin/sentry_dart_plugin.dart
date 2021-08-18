import 'dart:async';

import 'package:sentry_dart_plugin/sentry_dart_plugin.dart';

FutureOr<void> main(List<String> arguments) async {
  await SentryDartPlugin().run(arguments);
}
