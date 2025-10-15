@TestOn('vm')
library;

import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/isolate/isolate_logger.dart';

void _entryUnconfigured(SendPort sendPort) {
  try {
    IsolateLogger.log(SentryLevel.info, 'x');
    sendPort.send('no-error');
  } catch (e) {
    sendPort.send(e.runtimeType.toString());
  }
}

void main() {
  setUp(() {
    IsolateLogger.reset();
  });

  test('configure required before log (debug builds)', () async {
    final rp = ReceivePort();
    await Isolate.spawn<SendPort>(_entryUnconfigured, rp.sendPort,
        debugName: 'LoggerUnconfigured');
    final result = await rp.first;
    rp.close();

    expect(result, '_AssertionError');
  });

  test('fatal logs even when debug=false', () {
    IsolateLogger.configure(
      debug: false,
      level: SentryLevel.error,
      loggerName: 't',
    );
    expect(() => IsolateLogger.log(SentryLevel.fatal, 'fatal ok'),
        returnsNormally);
  });

  test('threshold gating (no-throw at info below warning)', () {
    IsolateLogger.configure(
      debug: true,
      level: SentryLevel.warning,
      loggerName: 't',
    );
    expect(
        () => IsolateLogger.log(SentryLevel.info, 'info ok'), returnsNormally);
    expect(() => IsolateLogger.log(SentryLevel.warning, 'warn ok'),
        returnsNormally);
  });

  test('prevents reconfiguration without reset', () {
    IsolateLogger.configure(
      debug: true,
      level: SentryLevel.info,
      loggerName: 't',
    );
    expect(
        () => IsolateLogger.configure(
              debug: false,
              level: SentryLevel.error,
              loggerName: 't2',
            ),
        throwsStateError);
  });
}
