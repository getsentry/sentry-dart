import 'package:sentry/src/utils/sample_rate_format.dart';
import 'package:test/test.dart';
import 'package:intl/intl.dart';

void main() {
  test('format', () {
    final inputsAndOutputs = [
      Tuple(0.0, '0'),
      Tuple(1.0, '1'),
      Tuple(0.1, '0.1'),
      Tuple(0.11, '0.11'),
      Tuple(0.19, '0.19'),
      Tuple(0.191, '0.191'),
      Tuple(0.1919, '0.1919'),
      Tuple(0.19191, '0.19191'),
      Tuple(0.191919, '0.191919'),
      Tuple(0.1919191, '0.1919191'),
      Tuple(0.19191919, '0.19191919'),
      Tuple(0.191919191, '0.191919191'),
      Tuple(0.1919191919, '0.1919191919'),
      Tuple(0.19191919191, '0.19191919191'),
      Tuple(0.191919191919, '0.191919191919'),
      Tuple(0.1919191919191, '0.1919191919191'),
      Tuple(0.19191919191919, '0.19191919191919'),
      Tuple(0.191919191919191, '0.191919191919191'),
      Tuple(0.1919191919191919, '0.1919191919191919'),
      Tuple(0.19191919191919199, '0.191919191919192'),
    ];

    for (final inputAndOutput in inputsAndOutputs) {
      expect(SampleRateFormat().format(inputAndOutput.i), inputAndOutput.o);
    }
  });

  test('intl platform difference', () {
    expect(
      NumberFormat('#.################').format(0.1919191919191919),
      '0.1919191919191919',
    );
  });

  test('intl platform difference 2', () {
    expect(
      NumberFormat('#.################').format(0.19191919191919199),
      '0.191919191919192',
    );
  });

  test('input smaller 0 is capped', () {
    expect(SampleRateFormat().format(-1), '0');
  });

  test('input larger 1 is capped', () {
    expect(SampleRateFormat().format(1.1), '1');
  });

  test('call with NaN returns 0', () {
    expect(SampleRateFormat().format(double.nan), '0');
  });
}

class Tuple {
  Tuple(this.i, this.o);
  final double i;
  final String o;
}
