import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  test('empty serializes to 0000000000000000', () {
    expect(SpanId.empty().toString(), '0000000000000000');
  });

  test('fromId serializes to 976e0cd945864f60', () {
    expect(SpanId.fromId('976e0cd945864f60').toString(), '976e0cd945864f60');
  });

  test('newId generates new id', () {
    expect(SpanId.newId().toString(), isNotNull);
  });

  test('equality check matches for same id', () {
    final id1 = SpanId.fromId('976e0cd945864f60');
    final id2 = SpanId.fromId('976e0cd945864f60');

    expect(id1, id2);
  });
}
