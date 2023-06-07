// ignore_for_file: deprecated_member_use

import 'package:dio/dio.dart';
import 'package:sentry_dio/src/dio_error_extractor.dart';
import 'package:test/test.dart';

void main() {
  late Fixture fixture;

  group(DioErrorExtractor, () {
    setUp(() {
      fixture = Fixture();
    });

    test('extracts error and stacktrace', () {
      final sut = fixture.getSut();
      late Error error;
      try {
        throw ArgumentError('foo bar');
      } on ArgumentError catch (e) {
        error = e;
      }
      final dioError = DioError(
        error: error,
        requestOptions: RequestOptions(path: '/foo/bar'),
      );

      final cause = sut.cause(dioError);

      expect(cause?.exception, error);
      expect(cause?.stackTrace, error.stackTrace);
    });

    test('extracts exception', () {
      final sut = fixture.getSut();

      final dioError = DioError(
        error: 'Some error',
        requestOptions: RequestOptions(path: '/foo/bar'),
      );

      final cause = sut.cause(dioError);

      expect(cause?.exception, 'Some error');
      expect(cause?.stackTrace, isNull);
    });

    test('extracts nothing with missing cause', () {
      final sut = fixture.getSut();

      final dioError = DioError(
        requestOptions: RequestOptions(path: '/foo/bar'),
      );

      final cause = sut.cause(dioError);

      expect(cause, isNull);
    });
  });
}

class Fixture {
  DioErrorExtractor getSut() {
    return DioErrorExtractor();
  }
}
