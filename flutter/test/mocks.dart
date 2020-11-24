import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';

class MockHub extends Mock implements Hub {}

class MockTransport extends Mock implements Transport {}

const fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';
