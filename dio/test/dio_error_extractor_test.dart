import 'package:dio/dio.dart';
import 'package:sentry_dio/src/dio_error_extractor.dart';
import 'package:test/test.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  test('$DioErrorExtractor extracts error and stacktrace', () {
    final sut = fixture.getSut();
    final exception = Exception('foo bar');
    final stacktrace = StackTrace.current;

    final dioError = DioError(
      error: exception,
      requestOptions: RequestOptions(path: '/foo/bar'),
    )..stackTrace = stacktrace;

    final cause = sut.cause(dioError);

    expect(cause?.exception, exception);
    expect(cause?.stackTrace, stacktrace);
  });

  test('$DioErrorExtractor extracts stacktrace only', () {
    final sut = fixture.getSut();
    final stacktrace = StackTrace.current;

    final dioError = DioError(
      requestOptions: RequestOptions(path: '/foo/bar'),
    )..stackTrace = stacktrace;

    final cause = sut.cause(dioError);

    expect(cause?.exception, 'DioError inner stacktrace');
    expect(cause?.stackTrace, stacktrace);
  });

  test('$DioErrorExtractor extracts nothing with missing stacktrace', () {
    final sut = fixture.getSut();
    final exception = Exception('foo bar');

    final dioError = DioError(
      error: exception,
      requestOptions: RequestOptions(path: '/foo/bar'),
    );

    final cause = sut.cause(dioError);

    expect(cause, isNull);
  });
}

class Fixture {
  DioErrorExtractor getSut() {
    return DioErrorExtractor();
  }
}
