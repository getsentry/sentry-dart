import 'package:sentry/src/exception_cause.dart';
import 'package:sentry/src/exception_cause_extractor.dart';
import 'package:test/test.dart';

import 'package:sentry/sentry.dart';

import 'mocks.dart';

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
      ExceptionACauseExtractor(),
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
}

class Fixture {
  final options = SentryOptions(dsn: fakeDsn);

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
  @override
  ExceptionCause? cause(ExceptionA error) {
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
