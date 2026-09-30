import 'package:sentry/sentry.dart';

const fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

SentryOptions defaultTestOptions() {
  return SentryOptions(dsn: fakeDsn)
    ..traceLifecycle = SentryTraceLifecycle.static
    // ignore: invalid_use_of_internal_member
    ..automatedTestMode = true;
}
