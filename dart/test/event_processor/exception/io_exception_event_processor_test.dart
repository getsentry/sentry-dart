@TestOn('vm')
library dart_test;

import 'dart:io';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/event_processor/exception/io_exception_event_processor.dart';
import 'package:test/test.dart';

void main() {
  group(IoExceptionEventProcessor, () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('adds $SentryRequest for $HttpException with uris', () {
      final enricher = fixture.getSut();
      final event = enricher.apply(
        SentryEvent(
          throwable: HttpException(
            '',
            uri: Uri.parse('https://example.org/foo/bar?foo=bar'),
          ),
        ),
        Hint(),
      );

      expect(event?.request, isNotNull);
      expect(event?.request?.url, 'https://example.org/foo/bar');
      expect(event?.request?.queryString, 'foo=bar');
    });

    test('no $SentryRequest for $HttpException without uris', () {
      final enricher = fixture.getSut();
      final event = enricher.apply(
        SentryEvent(
          throwable: HttpException(''),
        ),
        Hint(),
      );

      expect(event?.request, isNull);
    });

    test('adds $SentryRequest for $SocketException with addresses', () {
      final enricher = fixture.getSut();
      final event = enricher.apply(
        SentryEvent(
          throwable: SocketException(
            'Exception while connecting',
            osError: OSError('Connection reset by peer', 54),
            port: 12345,
            address: InternetAddress(
              '127.0.0.1',
              type: InternetAddressType.IPv4,
            ),
          ),
        ),
        Hint(),
      );

      expect(event?.request, isNotNull);
      expect(event?.request?.url, '127.0.0.1');

      // Due to the test setup, there's no SentryException for the SocketException.
      // And thus only one entry for the added OSError
      expect(event?.exceptions?.first.type, 'OSError');
      expect(
        event?.exceptions?.first.value,
        'OS Error: Connection reset by peer, errno = 54',
      );
      expect(event?.exceptions?.first.mechanism?.type, 'OSError');
      expect(event?.exceptions?.first.mechanism?.meta['errno']['number'], 54);
    });

    test('adds OSError SentryException for $FileSystemException', () {
      final enricher = fixture.getSut();
      final event = enricher.apply(
        SentryEvent(
          throwable: FileSystemException(
            'message',
            'path',
            OSError('Oh no :(', 42),
          ),
        ),
        Hint(),
      );

      // Due to the test setup, there's no SentryException for the FileSystemException.
      // And thus only one entry for the added OSError
      expect(event?.exceptions?.first.type, 'OSError');
      expect(
        event?.exceptions?.first.value,
        'OS Error: Oh no :(, errno = 42',
      );
      expect(event?.exceptions?.first.mechanism?.type, 'OSError');
      expect(event?.exceptions?.first.mechanism?.meta['errno']['number'], 42);
    });
  });
}

class Fixture {
  IoExceptionEventProcessor getSut() {
    return IoExceptionEventProcessor(SentryOptions.empty());
  }
}
