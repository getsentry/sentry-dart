import 'package:sentry_supabase/src/sentry_supabase_client_error.dart';
import 'package:sentry_supabase/src/sentry_supabase_exception_type_identifier.dart';
import 'package:test/test.dart';

void main() {
  late SentrySupabaseExceptionTypeIdentifier sut;

  setUp(() {
    sut = SentrySupabaseExceptionTypeIdentifier();
  });

  group('$SentrySupabaseExceptionTypeIdentifier', () {
    test('identifies $SentrySupabaseClientError', () {
      expect(
        sut.identifyType(SentrySupabaseClientError('reason')),
        'SentrySupabaseClientError',
      );
    });

    test('returns null for other exceptions', () {
      expect(sut.identifyType(StateError('nope')), isNull);
    });
  });
}
