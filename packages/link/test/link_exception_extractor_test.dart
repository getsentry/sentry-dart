import 'package:gql_link/gql_link.dart';
import 'package:sentry_link/src/extractors.dart';
import 'package:test/test.dart';

void main() {
  test('extractor can extract', () {
    final nestedException = LinkExceptionExtractor().cause(
      ResponseFormatException(
        originalException: Exception(),
        originalStackTrace: StackTrace.current,
      ),
    );

    expect(nestedException?.exception, isA<Exception>());
    expect(nestedException?.stackTrace, isNotNull);
  });
}
