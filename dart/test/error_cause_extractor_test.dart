import 'package:sentry/src/error_cause_extractor.dart';
import 'package:test/test.dart';

void main() {
  test('flatten', () {
    final errorC = ErrorC();
    final errorB = ErrorB(errorC);
    final errorA = ErrorA(errorB);

    final sut = ErrorCauseExtractor({
      ErrorA: ErrorACauseExtractor(),
      ErrorB: ErrorBCauseExtractor()
    });

    final flattened = sut.flatten(errorA);
    expect(flattened, [errorA, errorB, errorC]);
  });
}

class ErrorA {
  ErrorA(this.other);
  final ErrorB? other;
}

class ErrorB {
  ErrorB(this.anotherOther);
  final ErrorC? anotherOther;
}

class ErrorC {
  // I am empty inside
}

class ErrorACauseExtractor implements CauseExtractor<ErrorA> {
  @override
  Object? cause(ErrorA error) {
    return error.other;
  }
}

class ErrorBCauseExtractor implements CauseExtractor<ErrorB> {
  @override
  Object? cause(ErrorB error) {
    return error.anotherOther;
  }
}
