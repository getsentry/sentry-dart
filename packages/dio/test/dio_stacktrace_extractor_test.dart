// ignore_for_file: deprecated_member_use

import 'package:dio/dio.dart';
import 'package:sentry_dio/src/dio_stacktrace_extractor.dart';
import 'package:test/test.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group(DioStackTraceExtractor, () {
    test('extracts stacktrace', () {
      final sut = fixture.getSut();
      final exception = Exception('foo bar');
      final stacktrace = StackTrace.current;

      final dioError = DioError(
        error: exception,
        requestOptions: RequestOptions(path: '/foo/bar'),
        stackTrace: stacktrace,
      );

      final result = sut.stackTrace(dioError);

      expect(result, stacktrace);
    });
  });
}

class Fixture {
  DioStackTraceExtractor getSut() {
    return DioStackTraceExtractor();
  }
}
