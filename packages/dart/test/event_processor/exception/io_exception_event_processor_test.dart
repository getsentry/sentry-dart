@TestOn('vm')
library;

import 'dart:io';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/event_processor/exception/io_exception_event_processor.dart';
import 'package:test/test.dart';
import 'package:sentry/src/sentry_exception_factory.dart';

import '../../test_utils.dart';

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
      final throwable = SocketException(
        'Exception while connecting',
        osError: OSError('Connection reset by peer', 54),
        port: 12345,
        address: InternetAddress(
          '127.0.0.1',
          type: InternetAddressType.IPv4,
        ),
      );
      final sentryException =
          fixture.exceptionFactory.getSentryException(throwable);

      final event = enricher.apply(
        SentryEvent(
          throwable: throwable,
          exceptions: [sentryException],
        ),
        Hint(),
      );

      expect(event?.request, isNotNull);
      expect(event?.request?.url, '127.0.0.1');

      final rootException = event?.exceptions?.first;
      expect(rootException, sentryException);

      final childException = rootException?.exceptions?.first;
      expect(childException?.type, 'OSError');
      expect(childException?.value,
          'OS Error: Connection reset by peer, errno = 54');
      expect(childException?.mechanism?.type, 'OSError');
      expect(childException?.mechanism?.meta['errno']['number'], 54);
      expect(childException?.mechanism?.source, 'osError');
    });

    test('adds OSError SentryException for $FileSystemException', () {
      final enricher = fixture.getSut();
      final throwable = FileSystemException(
        'message',
        'path',
        OSError('Oh no :(', 42),
      );
      final sentryException =
          fixture.exceptionFactory.getSentryException(throwable);

      final event = enricher.apply(
        SentryEvent(
          throwable: throwable,
          exceptions: [sentryException],
        ),
        Hint(),
      );

      final rootException = event?.exceptions?.first;
      expect(rootException, sentryException);

      final childException = rootException?.exceptions?.firstOrNull;
      // Due to the test setup, there's no SentryException for the FileSystemException.
      // And thus only one entry for the added OSError
      expect(childException?.type, 'OSError');
      expect(
        childException?.value,
        'OS Error: Oh no :(, errno = 42',
      );
      expect(childException?.mechanism?.type, 'OSError');
      expect(childException?.mechanism?.meta['errno']['number'], 42);
      expect(childException?.mechanism?.source, 'osError');
    });
  });
}

class Fixture {
  final SentryOptions options = defaultTestOptions();

  // ignore: invalid_use_of_internal_member
  SentryExceptionFactory get exceptionFactory => options.exceptionFactory;

  IoExceptionEventProcessor getSut() {
    return IoExceptionEventProcessor(SentryOptions.empty());
  }
}
