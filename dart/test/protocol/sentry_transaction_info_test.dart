import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  group('$SentryTransactionInfo', () {
    final info = SentryTransactionInfo(
      'component',
      unknown: testUnknown,
    );

    final json = <String, dynamic>{'source': 'component'};
    json.addAll(testUnknown);

    test('returns source', () {
      expect(info.source, 'component');
    });

    test('toJson has source', () {
      expect(info.toJson(), json);
    });

    test('fromJson has source', () {
      final info = SentryTransactionInfo.fromJson({'source': 'component'});
      expect(info.source, 'component');
    });
  });
}
