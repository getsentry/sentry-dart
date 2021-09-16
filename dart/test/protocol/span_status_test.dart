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

  test('fromHttpStatusCode returns ok if 200', () {
    expect(SpanStatus.fromHttpStatusCode(200), SpanStatus.ok());
  });
}
