import 'package:mockito/annotations.dart';
import 'package:sentry/sentry.dart';

const fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

@GenerateMocks([Hub, Transport])
void main() {}
