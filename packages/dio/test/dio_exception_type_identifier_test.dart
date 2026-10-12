import 'package:dio/dio.dart';
import 'package:sentry_dio/src/dio_exception_type_identifier.dart';
import 'package:test/test.dart';

void main() {
  late DioExceptionTypeIdentifier sut;

  setUp(() {
    sut = DioExceptionTypeIdentifier();
  });

  group('$DioExceptionTypeIdentifier', () {
    test('identifies $DioException as DioException', () {
      final exception = DioException(
        requestOptions: RequestOptions(path: '/foo'),
      );

      expect(sut.identifyType(exception), 'DioException');
    });

    test('returns null for non-Dio exceptions', () {
      expect(sut.identifyType(StateError('nope')), isNull);
    });
  });
}
