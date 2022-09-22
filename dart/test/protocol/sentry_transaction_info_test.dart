import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  group('$SentryTransactionInfo', () {
    test('returns source', () {
      final info = SentryTransactionInfo('component');
      expect(info.source, 'component');
    });

    test('toJson has source', () {
      final info = SentryTransactionInfo('component');
      expect(info.toJson(), {'source': 'component'});
    });

    test('fromJson has source', () {
      final info = SentryTransactionInfo.fromJson({'source': 'component'});
      expect(info.source, 'component');
    });
  });
}
