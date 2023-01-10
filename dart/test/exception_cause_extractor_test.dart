import 'package:sentry/src/exception_cause.dart';
import 'package:sentry/src/exception_cause_extractor.dart';
import 'package:test/test.dart';

void main() {
  test('flatten', () {
    final errorC = ExceptionC();
    final errorB = ExceptionB(errorC);
    final errorA = ExceptionA(errorB);

    final sut = RecursiveExceptionCauseExtractor({
      ExceptionA: ExceptionACauseExtractor(),
      ExceptionB: ExceptionBCauseExtractor()
    });

    final flattened = sut.flatten(errorA, null);
    final actual = flattened.map((exceptionCause) => exceptionCause.exception);
    expect(actual, [errorA, errorB, errorC]);
  });
}

class ExceptionA {
  ExceptionA(this.other);
  final ExceptionB? other;
}

class ExceptionB {
  ExceptionB(this.anotherOther);
  final ExceptionC? anotherOther;
}

class ExceptionC {
  // I am empty inside
}

class ExceptionACauseExtractor implements ExceptionCauseExtractor<ExceptionA> {
  @override
  ExceptionCause? cause(ExceptionA error) {
    return ExceptionCause(error.other, null);
  }
}

class ExceptionBCauseExtractor implements ExceptionCauseExtractor<ExceptionB> {
  @override
  ExceptionCause? cause(ExceptionB error) {
    return ExceptionCause(error.anotherOther, null);
  }
}
