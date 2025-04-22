import 'package:sentry_supabase/sentry_supabase.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    final client = SentrySupabaseClient();

    setUp(() {
      // Additional setup goes here.
    });

    test('Sample test', () {
      expect(client, isNotNull);
    });
  });
}
