import 'package:sentry/src/feature_flags/xor_shift_rand.dart';
import 'package:test/test.dart';

void main() {
  test('test random determinisc generator', () {
    final rand = XorShiftRandom('wohoo');

    expect(rand.nextu32(), 3709882355);
    expect(rand.nextu32(), 3406141351);
    expect(rand.nextu32(), 2220835615);
    expect(rand.nextu32(), 1978561524);
    expect(rand.nextu32(), 2006162129);
    expect(rand.nextu32(), 1526862107);
    expect(rand.nextu32(), 2715875971);
    expect(rand.nextu32(), 3524055327);
    expect(rand.nextu32(), 1313248726);
    expect(rand.nextu32(), 1591659718);
  });
}
