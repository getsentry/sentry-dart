import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';

class MockHub extends Mock implements Hub {}

const fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';
