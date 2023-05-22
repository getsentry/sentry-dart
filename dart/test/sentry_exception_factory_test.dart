import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_exception_factory.dart';
import 'package:test/test.dart';

import 'mocks.dart';

void main() {
  final fixture = Fixture();

  test('getSentryException with frames', () {
    SentryException sentryException;
    try {
      throw StateError('a state error');
    } catch (err, stacktrace) {
      sentryException = fixture.getSut().getSentryException(
            err,
            stackTrace: stacktrace,
          );
    }

    expect(sentryException.type, 'StateError');
    expect(sentryException.stackTrace!.frames, isNotEmpty);
  });

  test('getSentryException without frames', () {
    SentryException sentryException;
    try {
      throw StateError('a state error');
    } catch (err, _) {
      sentryException = fixture.getSut().getSentryException(
            err,
            stackTrace: '',
          );
    }

    expect(sentryException.type, 'StateError');
    expect(sentryException.stackTrace, isNull);
  });

  test('getSentryException without frames', () {
    SentryException sentryException;
    try {
      throw StateError('a state error');
    } catch (err, _) {
      sentryException = fixture.getSut().getSentryException(
            err,
            stackTrace: '',
          );
    }

    expect(sentryException.type, 'StateError');
    expect(sentryException.stackTrace, isNull);
  });

  test('should not override event.stacktrace', () {
    SentryException sentryException;
    try {
      throw StateError('a state error');
    } catch (err, _) {
      sentryException = fixture.getSut().getSentryException(
        err,
        stackTrace: '''
#0      baz (file:///pathto/test.dart:50:3)
<asynchronous suspension>
#1      bar (file:///pathto/test.dart:46:9)
      ''',
      );
    }

    expect(sentryException.type, 'StateError');
    expect(sentryException.stackTrace!.frames.first.lineNo, 46);
    expect(sentryException.stackTrace!.frames.first.colNo, 9);
    expect(sentryException.stackTrace!.frames.first.fileName, 'test.dart');
  });

  test('should extract stackTrace from custom exception', () {
    fixture.options
        .addExceptionStackTraceExtractor(CustomExceptionStackTraceExtractor());

    SentryException sentryException;
    try {
      throw CustomException(StackTrace.fromString('''
#0      baz (file:///pathto/test.dart:50:3)
<asynchronous suspension>
#1      bar (file:///pathto/test.dart:46:9)
      '''));
    } catch (err, _) {
      sentryException = fixture.getSut().getSentryException(
            err,
          );
    }

    expect(sentryException.type, 'CustomException');
    expect(sentryException.stackTrace!.frames.first.lineNo, 46);
    expect(sentryException.stackTrace!.frames.first.colNo, 9);
    expect(sentryException.stackTrace!.frames.first.fileName, 'test.dart');
  });

  test('should not fail when stackTrace property does not exist', () {
    SentryException sentryException;
    try {
      throw Object();
    } catch (err, _) {
      sentryException = fixture.getSut().getSentryException(
            err,
          );
    }

    expect(sentryException.type, 'Object');
    expect(sentryException.stackTrace, isNotNull);
  });

  test('getSentryException with not thrown Error and frames', () {
    final sentryException = fixture.getSut().getSentryException(
          CustomError(),
        );

    expect(sentryException.type, 'CustomError');
    expect(sentryException.stackTrace?.frames, isNotEmpty);

    // skip on browser because [StackTrace.current] still returns null
  }, onPlatform: {'browser': Skip()});

  test('getSentryException with not thrown Error and empty frames', () {
    final sentryException = fixture
        .getSut()
        .getSentryException(CustomError(), stackTrace: StackTrace.empty);

    expect(sentryException.type, 'CustomError');
    expect(sentryException.stackTrace?.frames, isNotEmpty);

    // skip on browser because [StackTrace.current] still returns null
  }, onPlatform: {'browser': Skip()});

  test('reads the snapshot from the mechanism', () {
    final error = StateError('test-error');
    final mechanism = Mechanism(type: 'Mechanism');
    final throwableMechanism = ThrowableMechanism(
      mechanism,
      error,
      snapshot: true,
    );

    SentryException sentryException;
    try {
      throw throwableMechanism;
    } catch (err, stackTrace) {
      sentryException = fixture.getSut().getSentryException(
            throwableMechanism,
            stackTrace: stackTrace,
          );
    }

    expect(sentryException.stackTrace!.snapshot, true);
  });

  test('getSentryException adds throwable', () {
    SentryException sentryException;
    dynamic throwable;
    try {
      throw StateError('a state error');
    } catch (err, stacktrace) {
      throwable = err;
      sentryException = fixture.getSut().getSentryException(
            err,
            stackTrace: stacktrace,
          );
    }

    expect(sentryException.throwable, throwable);
  });

  test('should not assigns stackTrace string to value', () {
    final stackTraceError = StackTraceError();
    final sentryException =
        fixture.getSut().getSentryException(stackTraceError);
    final expected = '''
StackTraceError()
Some random description''';

    expect(sentryException.value, expected);
  });
}

class CustomError extends Error {}

class CustomException implements Exception {
  final StackTrace stackTrace;

  CustomException(this.stackTrace);
}

class CustomExceptionStackTraceExtractor
    extends ExceptionStackTraceExtractor<CustomException> {
  @override
  StackTrace? stackTrace(CustomException error) {
    return error.stackTrace;
  }
}

class StackTraceError extends Error {
  @override
  String toString() {
    return '''
StackTraceError()
Some random description

#0      baz (file:///pathto/test.dart:50:3)
<asynchronous suspension>
#1      bar (file:///pathto/test.dart:46:9)''';
  }
}

class Fixture {
  final options = SentryOptions(dsn: fakeDsn);

  SentryExceptionFactory getSut() {
    return SentryExceptionFactory(options);
  }
}
