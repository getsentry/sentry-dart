import 'package:sentry/src/exception_cause.dart';
import 'package:sentry/src/exception_cause_extractor.dart';
import 'package:sentry/src/recursive_exception_cause_extractor.dart';
import 'package:sentry/src/protocol/mechanism.dart';
import 'package:sentry/src/throwable_mechanism.dart';
import 'package:test/test.dart';
import 'test_utils.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  test('flatten', () {
    final errorC = ExceptionC();
    final errorB = ExceptionB(errorC);
    final errorA = ExceptionA(errorB);

    fixture.options.addExceptionCauseExtractor(
      ExceptionACauseExtractor(false),
    );

    fixture.options.addExceptionCauseExtractor(
      ExceptionBCauseExtractor(),
    );

    final sut = fixture.getSut();

    final flattened = sut.flatten(errorA, null);
    final actual = flattened.map((exceptionCause) => exceptionCause.exception);
    expect(actual, [errorA, errorB, errorC]);
  });

  test('flatten breaks circularity', () {
    final a = ExceptionCircularA();
    final b = ExceptionCircularB();
    a.other = b;
    b.other = a;

    fixture.options.addExceptionCauseExtractor(
      ExceptionCircularAExtractor(),
    );

    fixture.options.addExceptionCauseExtractor(
      ExceptionCircularBExtractor(),
    );

    final sut = fixture.getSut();

    final flattened = sut.flatten(a, null);
    final actual = flattened.map((exceptionCause) => exceptionCause.exception);

    expect(actual, [a, b]);
  });

  test('flatten preserves throwable mechanism', () {
    final errorC = ExceptionC();
    final errorB = ExceptionB(errorC);
    final errorA = ExceptionA(errorB);

    fixture.options.addExceptionCauseExtractor(
      ExceptionACauseExtractor(false),
    );

    fixture.options.addExceptionCauseExtractor(
      ExceptionBCauseExtractor(),
    );

    final mechanism = Mechanism(type: "foo");
    final throwableMechanism = ThrowableMechanism(mechanism, errorA);

    final sut = fixture.getSut();
    final flattened = sut.flatten(throwableMechanism, null);

    final actual = flattened.map((exceptionCause) => exceptionCause.exception);
    expect(actual, [throwableMechanism, errorB, errorC]);
  });

  test('throw during extractions is handled', () {
    final errorB = ExceptionB(null);
    final errorA = ExceptionA(errorB);

    fixture.options.addExceptionCauseExtractor(
      ExceptionACauseExtractor(true),
    );

    fixture.options.addExceptionCauseExtractor(
      ExceptionBCauseExtractor(),
    );

    fixture.options.automatedTestMode = false;
    final sut = fixture.getSut();

    final flattened = sut.flatten(errorA, null);
    final actual = flattened.map((exceptionCause) => exceptionCause.exception);

    expect(actual, [errorA]);
  });
}

class Fixture {
  final options = defaultTestOptions();

  RecursiveExceptionCauseExtractor getSut() {
    return RecursiveExceptionCauseExtractor(options);
  }
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

class ExceptionACauseExtractor extends ExceptionCauseExtractor<ExceptionA> {
  ExceptionACauseExtractor(this.throwing);

  final bool throwing;

  @override
  ExceptionCause? cause(ExceptionA error) {
    if (throwing) {
      throw StateError("Unexpected exception");
    }
    return ExceptionCause(error.other, null);
  }
}

class ExceptionBCauseExtractor extends ExceptionCauseExtractor<ExceptionB> {
  @override
  ExceptionCause? cause(ExceptionB error) {
    return ExceptionCause(error.anotherOther, null);
  }
}

class ExceptionCircularA {
  ExceptionCircularB? other;
}

class ExceptionCircularB {
  ExceptionCircularA? other;
}

class ExceptionCircularAExtractor
    extends ExceptionCauseExtractor<ExceptionCircularA> {
  @override
  ExceptionCause? cause(ExceptionCircularA error) {
    return ExceptionCause(error.other, null);
  }
}

class ExceptionCircularBExtractor
    extends ExceptionCauseExtractor<ExceptionCircularB> {
  @override
  ExceptionCause? cause(ExceptionCircularB error) {
    return ExceptionCause(error.other, null);
  }
}
