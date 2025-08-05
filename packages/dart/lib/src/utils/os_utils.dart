import 'package:meta/meta.dart';
import '../protocol/sentry_operating_system.dart';

import '_web_get_sentry_operating_system.dart'
    if (dart.library.io) '_io_get_sentry_operating_system.dart' as os_getter;

@internal
SentryOperatingSystem getSentryOperatingSystem({
  String? name,
  String? rawDescription,
}) {
  return os_getter.getSentryOperatingSystem(
      name: name, rawDescription: rawDescription);
}
