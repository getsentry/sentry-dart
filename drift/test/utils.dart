import 'package:sentry/sentry.dart';

final fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

SentryOptions defaultTestOptions() {
  // ignore: invalid_use_of_internal_member
  return SentryOptions(dsn: fakeDsn)..automatedTestMode = true;
}
