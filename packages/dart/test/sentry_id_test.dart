import 'package:sentry/src/protocol/sentry_id.dart';
import 'package:test/test.dart';

void main() {
  test('empty id', () {
    expect(SentryId.empty().toString(), '00000000000000000000000000000000');
  });

  test('empty id equals from empty id', () {
    expect(
      SentryId.empty(),
      SentryId.fromId('00000000000000000000000000000000'),
    );
  });

  test('uuid format with dashes', () {
    expect(
      SentryId.fromId('00000000-0000-0000-0000-000000000000'),
      SentryId.empty(),
    );
  });

  test('empty id equality', () {
    expect(SentryId.empty(), SentryId.empty());
  });

  test('id roundtrip', () {
    final id = SentryId.newId();
    expect(id, SentryId.fromId(id.toString()));
  });

  test('newId should not be equal to newId', () {
    expect(SentryId.newId() == SentryId.newId(), false);
  });
}
