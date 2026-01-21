import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  group('TracingStatus', () {
    group('fromHttpStatusCode', () {
      test('maps 2xx to ok', () {
        expect(
          TracingStatusExtension.fromHttpStatusCode(200),
          TracingStatus.ok,
        );
        expect(
          TracingStatusExtension.fromHttpStatusCode(201),
          TracingStatus.ok,
        );
        expect(
          TracingStatusExtension.fromHttpStatusCode(299),
          TracingStatus.ok,
        );
      });

      test('maps 400 to invalidArgument', () {
        expect(
          TracingStatusExtension.fromHttpStatusCode(400),
          TracingStatus.invalidArgument,
        );
      });

      test('maps 401 to unauthenticated', () {
        expect(
          TracingStatusExtension.fromHttpStatusCode(401),
          TracingStatus.unauthenticated,
        );
      });

      test('maps 403 to permissionDenied', () {
        expect(
          TracingStatusExtension.fromHttpStatusCode(403),
          TracingStatus.permissionDenied,
        );
      });

      test('maps 404 to notFound', () {
        expect(
          TracingStatusExtension.fromHttpStatusCode(404),
          TracingStatus.notFound,
        );
      });

      test('maps 409 to alreadyExists', () {
        expect(
          TracingStatusExtension.fromHttpStatusCode(409),
          TracingStatus.alreadyExists,
        );
      });

      test('maps 429 to resourceExhausted', () {
        expect(
          TracingStatusExtension.fromHttpStatusCode(429),
          TracingStatus.resourceExhausted,
        );
      });

      test('maps 499 to cancelled', () {
        expect(
          TracingStatusExtension.fromHttpStatusCode(499),
          TracingStatus.cancelled,
        );
      });

      test('maps 500 to internalError', () {
        expect(
          TracingStatusExtension.fromHttpStatusCode(500),
          TracingStatus.internalError,
        );
      });

      test('maps 501 to unimplemented', () {
        expect(
          TracingStatusExtension.fromHttpStatusCode(501),
          TracingStatus.unimplemented,
        );
      });

      test('maps 503 to unavailable', () {
        expect(
          TracingStatusExtension.fromHttpStatusCode(503),
          TracingStatus.unavailable,
        );
      });

      test('maps 504 to deadlineExceeded', () {
        expect(
          TracingStatusExtension.fromHttpStatusCode(504),
          TracingStatus.deadlineExceeded,
        );
      });

      test('maps other 4xx to invalidArgument', () {
        expect(
          TracingStatusExtension.fromHttpStatusCode(402),
          TracingStatus.invalidArgument,
        );
        expect(
          TracingStatusExtension.fromHttpStatusCode(410),
          TracingStatus.invalidArgument,
        );
      });

      test('maps other 5xx to internalError', () {
        expect(
          TracingStatusExtension.fromHttpStatusCode(502),
          TracingStatus.internalError,
        );
        expect(
          TracingStatusExtension.fromHttpStatusCode(599),
          TracingStatus.internalError,
        );
      });

      test('maps 1xx to unknown', () {
        expect(
          TracingStatusExtension.fromHttpStatusCode(100),
          TracingStatus.unknown,
        );
      });

      test('maps 3xx to unknown', () {
        expect(
          TracingStatusExtension.fromHttpStatusCode(301),
          TracingStatus.unknown,
        );
      });
    });
  });
}
