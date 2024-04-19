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

  test('should remove stackTrace string from value', () {
    final stackTraceError = StackTraceError();
    final sentryException = fixture.getSut().getSentryException(stackTraceError,
        stackTrace: StackTraceErrorStackTrace());
    final expected =
        "NetworkError(type: NetworkErrorType.unknown, error: Instance of 'iH')";

    expect(sentryException.value, expected);
  });

  test('no empty value', () {
    final stackTraceError = StackTraceError();
    stackTraceError.prefix = "";
    final sentryException = fixture.getSut().getSentryException(stackTraceError,
        stackTrace: StackTraceErrorStackTrace());

    expect(sentryException.value, isNull);
  });

  test(
      'set snapshot to true when no stracktrace is present & attachStacktrace == true',
      () {
    final sentryException =
        fixture.getSut(attachStacktrace: true).getSentryException(Object());

    expect(sentryException.stackTrace!.snapshot, true);
  });

  test(
      'set snapshot to false when no stracktrace is present & attachStacktrace == false',
      () {
    final sentryException =
        fixture.getSut(attachStacktrace: false).getSentryException(Object());

    expect(sentryException.stackTrace!.snapshot, true);
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
  var prefix =
      "NetworkError(type: NetworkErrorType.unknown, error: Instance of 'iH')";

  @override
  String toString() {
    return '''
$prefix

pid: 9437, tid: 10069, name 1.ui
os: android arch: arm64 comp: yes sim: no
build_id: 'bca64abfdfcc84d231bb8f1ccdbfbd8d'
isolate_dso_base: 752602b000, vm_dso_base: 752602b000
isolate_instructions: 7526344980, vm_instructions: 752633f000
#00 abs 00000075266c2fbf virt 0000000000697fbf _kDartIsolateSnapshotInstructions+0x37e63f
#1 abs 000000752685211f virt 000000000082711f _kDartIsolateSnapshotInstructions+0x50d79f
#2 abs 0000007526851cb3 virt 0000000000826cb3 _kDartIsolateSnapshotInstructions+0x50d333
#3 abs 0000007526851c63 virt 0000000000826c63 _kDartIsolateSnapshotInstructions+0x50d2e3
#4 abs 0000007526851bf3 virt 0000000000826bf3 _kDartIsolateSnapshotInstructions+0x50d273
#5 abs 0000007526a0b44b virt 00000000009e044b _kDartIsolateSnapshotInstructions+0x6c6acb
#6 abs 0000007526a068a7 virt 00000000009db8a7 _kDartIsolateSnapshotInstructions+0x6c1f27
#7 abs 0000007526b57a2b virt 0000000000b2ca2b _kDartIsolateSnapshotInstructions+0x8130ab
#8 abs 0000007526b5d93b virt 0000000000b3293b _kDartIsolateSnapshotInstructions+0x818fbb
#9 abs 0000007526a2333b virt 00000000009f833b _kDartIsolateSnapshotInstructions+0x6de9bb
#10 abs 0000007526937957 virt 000000000090c957 _kDartIsolateSnapshotInstructions+0x5f2fd7
#11 abs 0000007526a243a3 virt 00000000009f93a3 _kDartIsolateSnapshotInstructions+0x6dfa23
#12 abs 000000752636273b virt 000000000033773b _kDartIsolateSnapshotInstructions+0x1ddbb
#13 abs 0000007526a36ac3 virt 0000000000a0bac3 _kDartIsolateSnapshotInstructions+0x6f2143
#14 abs 00000075263626af virt 00000000003376af _kDartIsolateSnapshotInstructions+0x1dd2f''';
  }
}

class StackTraceErrorStackTrace extends StackTrace {
  @override
  String toString() {
    return '''
pid: 9437, tid: 10069, name 1.ui
os: android arch: arm64 comp: yes sim: no
build_id: 'bca64abfdfcc84d231bb8f1ccdbfbd8d'
isolate_dso_base: 752602b000, vm_dso_base: 752602b000
isolate_instructions: 7526344980, vm_instructions: 752633f000
#00 abs 00000075266c2fbf virt 0000000000697fbf _kDartIsolateSnapshotInstructions+0x37e63f
#1 abs 000000752685211f virt 000000000082711f _kDartIsolateSnapshotInstructions+0x50d79f
#2 abs 0000007526851cb3 virt 0000000000826cb3 _kDartIsolateSnapshotInstructions+0x50d333
#3 abs 0000007526851c63 virt 0000000000826c63 _kDartIsolateSnapshotInstructions+0x50d2e3
#4 abs 0000007526851bf3 virt 0000000000826bf3 _kDartIsolateSnapshotInstructions+0x50d273
#5 abs 0000007526a0b44b virt 00000000009e044b _kDartIsolateSnapshotInstructions+0x6c6acb
#6 abs 0000007526a068a7 virt 00000000009db8a7 _kDartIsolateSnapshotInstructions+0x6c1f27
#7 abs 0000007526b57a2b virt 0000000000b2ca2b _kDartIsolateSnapshotInstructions+0x8130ab
#8 abs 0000007526b5d93b virt 0000000000b3293b _kDartIsolateSnapshotInstructions+0x818fbb
#9 abs 0000007526a2333b virt 00000000009f833b _kDartIsolateSnapshotInstructions+0x6de9bb
#10 abs 0000007526937957 virt 000000000090c957 _kDartIsolateSnapshotInstructions+0x5f2fd7
#11 abs 0000007526a243a3 virt 00000000009f93a3 _kDartIsolateSnapshotInstructions+0x6dfa23
#12 abs 000000752636273b virt 000000000033773b _kDartIsolateSnapshotInstructions+0x1ddbb
#13 abs 0000007526a36ac3 virt 0000000000a0bac3 _kDartIsolateSnapshotInstructions+0x6f2143
#14 abs 00000075263626af virt 00000000003376af _kDartIsolateSnapshotInstructions+0x1dd2f''';
  }
}

class Fixture {
  final options = SentryOptions(dsn: fakeDsn);

  SentryExceptionFactory getSut({bool attachStacktrace = true}) {
    options.attachStacktrace = true;
    return SentryExceptionFactory(options);
  }
}
