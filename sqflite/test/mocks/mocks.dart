import 'package:mockito/annotations.dart';
// import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sqflite/sqflite.dart';

// @GenerateNiceMocks([MockSpec<Batch>()])
// class MockBatch extends Mock implements Batch {}

// @GenerateNiceMocks([MockSpec<SentryTracer>()])
// class MockSentryTracer extends Mock implements SentryTracer {}

@GenerateNiceMocks([MockSpec<Hub>(), MockSpec<Batch>()])
import 'mocks.mocks.dart';
