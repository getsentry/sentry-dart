import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/dart_exception_type_identifier.dart';
import 'package:sentry/src/sentry_exception_factory.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'mocks.mocks.dart';
import 'mocks/mock_transport.dart';
import 'sentry_client_test.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group('ExceptionTypeIdentifiers', () {
    test('first in the list will be processed first', () {
      fixture.options
          .prependExceptionTypeIdentifier(DartExceptionTypeIdentifier());
      fixture.options
          .prependExceptionTypeIdentifier(ObfuscatedExceptionIdentifier());

      final factory = SentryExceptionFactory(fixture.options);
      final sentryException = factory.getSentryException(ObfuscatedException());

      expect(sentryException.type, equals('ObfuscatedException'));
    });
  });

  group('CachingExceptionTypeIdentifier', () {
    late MockExceptionTypeIdentifier mockIdentifier;
    late CachingExceptionTypeIdentifier cachingIdentifier;

    setUp(() {
      mockIdentifier = MockExceptionTypeIdentifier();
      cachingIdentifier = CachingExceptionTypeIdentifier(mockIdentifier);
    });

    test('should return cached result for known types', () {
      final exception = Exception('Test');
      when(mockIdentifier.identifyType(exception)).thenReturn('TestException');

      expect(
          cachingIdentifier.identifyType(exception), equals('TestException'));
      expect(
          cachingIdentifier.identifyType(exception), equals('TestException'));
      expect(
          cachingIdentifier.identifyType(exception), equals('TestException'));

      verify(mockIdentifier.identifyType(exception)).called(1);
    });

    test('should not cache unknown types', () {
      final exception = ObfuscatedException();

      when(mockIdentifier.identifyType(exception)).thenReturn(null);

      expect(cachingIdentifier.identifyType(exception), isNull);
      expect(cachingIdentifier.identifyType(exception), isNull);
      expect(cachingIdentifier.identifyType(exception), isNull);

      verify(mockIdentifier.identifyType(exception)).called(3);
    });

    test('should return null for unknown exception type', () {
      final exception = Exception('Unknown');
      when(mockIdentifier.identifyType(exception)).thenReturn(null);

      expect(cachingIdentifier.identifyType(exception), isNull);
    });

    test('should handle different exception types separately', () {
      final exception1 = Exception('Test1');
      final exception2 = FormatException('Test2');

      when(mockIdentifier.identifyType(exception1)).thenReturn('Exception');
      when(mockIdentifier.identifyType(exception2))
          .thenReturn('FormatException');

      expect(cachingIdentifier.identifyType(exception1), equals('Exception'));
      expect(cachingIdentifier.identifyType(exception2),
          equals('FormatException'));

      // Call again to test caching
      expect(cachingIdentifier.identifyType(exception1), equals('Exception'));
      expect(cachingIdentifier.identifyType(exception2),
          equals('FormatException'));

      verify(mockIdentifier.identifyType(exception1)).called(1);
      verify(mockIdentifier.identifyType(exception2)).called(1);
    });
  });

  group('Integration test', () {
    setUp(() {
      fixture.options.transport = MockTransport();
    });

    test(
        'should capture CustomException as exception type with custom identifier',
        () async {
      fixture.options
          .prependExceptionTypeIdentifier(ObfuscatedExceptionIdentifier());

      final client = SentryClient(fixture.options);

      await client.captureException(ObfuscatedException());

      final transport = fixture.options.transport as MockTransport;
      final capturedEnvelope = transport.envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(
          capturedEvent.exceptions!.first.type, equals('ObfuscatedException'));
    });

    test(
        'should capture PlaceHolderException as exception type without custom identifier',
        () async {
      final client = SentryClient(fixture.options);

      await client.captureException(ObfuscatedException());

      final transport = fixture.options.transport as MockTransport;
      final capturedEnvelope = transport.envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(
          capturedEvent.exceptions!.first.type, equals('PlaceHolderException'));
    });
  });
}

class Fixture {
  SentryOptions options = SentryOptions(dsn: fakeDsn);
}

// We use this PlaceHolder exception to mimic an obfuscated runtimeType
class PlaceHolderException implements Exception {}

class ObfuscatedException implements Exception {
  @override
  Type get runtimeType => PlaceHolderException;
}

class ObfuscatedExceptionIdentifier implements ExceptionTypeIdentifier {
  @override
  String? identifyType(dynamic throwable) {
    if (throwable is ObfuscatedException) return 'ObfuscatedException';
    return null;
  }
}
