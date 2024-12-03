import 'package:sentry_flutter/sentry_flutter.dart';

const fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

void defaultTestOptionsInitializer(SentryFlutterOptions options) {
  options.dsn = fakeDsn;
  // ignore: invalid_use_of_internal_member
  options.automatedTestMode = true;
}
