import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  test('SpanStatus ok', () {
    expect(SpanStatus.ok().toString(), 'ok');
  });

  test('SpanStatus cancelled', () {
    expect(SpanStatus.cancelled().toString(), 'cancelled');
  });

  test('SpanStatus internalError', () {
    expect(SpanStatus.internalError().toString(), 'internal_error');
  });

  test('SpanStatus unknown', () {
    expect(SpanStatus.unknown().toString(), 'unknown');
  });

  test('SpanStatus unknownError', () {
    expect(SpanStatus.unknownError().toString(), 'unknown_error');
  });

  test('SpanStatus invalidArgument', () {
    expect(SpanStatus.invalidArgument().toString(), 'invalid_argument');
  });

  test('SpanStatus deadlineExceeded', () {
    expect(SpanStatus.deadlineExceeded().toString(), 'deadline_exceeded');
  });

  test('SpanStatus notFound', () {
    expect(SpanStatus.notFound().toString(), 'not_found');
  });

  test('SpanStatus alreadyExists', () {
    expect(SpanStatus.alreadyExists().toString(), 'already_exists');
  });

  test('SpanStatus permissionDenied', () {
    expect(SpanStatus.permissionDenied().toString(), 'permission_denied');
  });

  test('SpanStatus resourceExhausted', () {
    expect(SpanStatus.resourceExhausted().toString(), 'resource_exhausted');
  });

  test('SpanStatus failedPrecondition', () {
    expect(SpanStatus.failedPrecondition().toString(), 'failed_precondition');
  });

  test('SpanStatus aborted', () {
    expect(SpanStatus.aborted().toString(), 'aborted');
  });

  test('SpanStatus outOfRange', () {
    expect(SpanStatus.outOfRange().toString(), 'out_of_range');
  });

  test('SpanStatus unimplemented', () {
    expect(SpanStatus.unimplemented().toString(), 'unimplemented');
  });

  test('SpanStatus unavailable', () {
    expect(SpanStatus.unavailable().toString(), 'unavailable');
  });

  test('SpanStatus dataLoss', () {
    expect(SpanStatus.dataLoss().toString(), 'data_loss');
  });

  test('SpanStatus unauthenticated', () {
    expect(SpanStatus.unauthenticated().toString(), 'unauthenticated');
  });

  test('fromHttpStatusCode returns ok if 200 to 299', () {
    expect(SpanStatus.fromHttpStatusCode(200), SpanStatus.ok());
    expect(SpanStatus.fromHttpStatusCode(299), SpanStatus.ok());
  });

  test('fromHttpStatusCode returns cancelled if 499', () {
    expect(SpanStatus.fromHttpStatusCode(499), SpanStatus.cancelled());
  });

  test('fromHttpStatusCode returns unknown if 500', () {
    expect(SpanStatus.fromHttpStatusCode(500), SpanStatus.unknown());
  });

  test('fromHttpStatusCode returns invalid argument if 500', () {
    expect(SpanStatus.fromHttpStatusCode(400), SpanStatus.invalidArgument());
  });

  test('fromHttpStatusCode returns invalid argument if 504', () {
    expect(SpanStatus.fromHttpStatusCode(504), SpanStatus.deadlineExceeded());
  });

  test('fromHttpStatusCode returns not found if 404', () {
    expect(SpanStatus.fromHttpStatusCode(404), SpanStatus.notFound());
  });

  test('fromHttpStatusCode returns already exists if 409', () {
    expect(SpanStatus.fromHttpStatusCode(409), SpanStatus.alreadyExists());
  });

  test('fromHttpStatusCode returns permissionDenied if 403', () {
    expect(SpanStatus.fromHttpStatusCode(403), SpanStatus.permissionDenied());
  });

  test('fromHttpStatusCode returns resourceExhausted if 429', () {
    expect(SpanStatus.fromHttpStatusCode(429), SpanStatus.resourceExhausted());
  });

  test('fromHttpStatusCode returns unimplemented if 501', () {
    expect(SpanStatus.fromHttpStatusCode(501), SpanStatus.unimplemented());
  });

  test('fromHttpStatusCode returns unavailable if 503', () {
    expect(SpanStatus.fromHttpStatusCode(503), SpanStatus.unavailable());
  });

  test('fromHttpStatusCode returns unauthenticated if 401', () {
    expect(SpanStatus.fromHttpStatusCode(401), SpanStatus.unauthenticated());
  });

  test('fromHttpStatusCode returns unknownError if not found', () {
    expect(SpanStatus.fromHttpStatusCode(100), SpanStatus.unknownError());
  });

  test('fromHttpStatusCode returns fallback if not found', () {
    expect(
        SpanStatus.fromHttpStatusCode(
          101,
          fallback: SpanStatus.aborted(),
        ),
        SpanStatus.aborted());
  });
}
