import 'package:sentry/sentry.dart';
import 'package:test/test.dart';
import 'test_utils.dart';
import 'mocks/mock_hub.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  void verifyCaptureLog(SentryLogLevel level) {
    expect(fixture.hub.captureLogCalls.length, 1);
    final capturedLog = fixture.hub.captureLogCalls[0].log;

    expect(capturedLog.timestamp, fixture.timestamp);
    expect(capturedLog.level, level);
    expect(capturedLog.body, 'test');
    expect(capturedLog.attributes, fixture.attributes);
  }

  test('sentry logger', () {
    final logger = fixture.getSut();

    logger.info('test', attributes: fixture.attributes);

    verifyCaptureLog(SentryLogLevel.info);
  });

  test('trace', () {
    final logger = fixture.getSut();

    logger.info('test', attributes: fixture.attributes);

    verifyCaptureLog(SentryLogLevel.info);
  });

  test('debug', () {
    final logger = fixture.getSut();

    logger.debug('test', attributes: fixture.attributes);

    verifyCaptureLog(SentryLogLevel.debug);
  });

  test('info', () {
    final logger = fixture.getSut();

    logger.info('test', attributes: fixture.attributes);

    verifyCaptureLog(SentryLogLevel.info);
  });

  test('warn', () {
    final logger = fixture.getSut();

    logger.warn('test', attributes: fixture.attributes);

    verifyCaptureLog(SentryLogLevel.warn);
  });

  test('error', () {
    final logger = fixture.getSut();

    logger.error('test', attributes: fixture.attributes);

    verifyCaptureLog(SentryLogLevel.error);
  });

  test('fatal', () {
    final logger = fixture.getSut();

    logger.fatal('test', attributes: fixture.attributes);

    verifyCaptureLog(SentryLogLevel.fatal);
  });

  test('logs to hub options when provided', () {
    final mockLogCallback = _MockSdkLogCallback();

    // Set the mock log callback on the fixture hub
    fixture.hub.options.log = mockLogCallback.call;
    fixture.hub.options.debug = true;
    fixture.hub.options.diagnosticLevel = SentryLevel.debug;

    final logger = SentryLogger(
      () => fixture.timestamp,
      hub: fixture.hub,
    );

    logger.trace('test message', attributes: fixture.attributes);

    // Verify that both hub.captureLog and our callback were called
    expect(fixture.hub.captureLogCalls.length, 1);
    expect(mockLogCallback.calls.length, 1);

    // Verify the captured log has the right content
    final capturedLog = fixture.hub.captureLogCalls[0].log;
    expect(capturedLog.level, SentryLogLevel.trace);
    expect(capturedLog.body, 'test message');
    expect(capturedLog.attributes, fixture.attributes);

    // Verify the log callback was called with the right parameters
    final logCall = mockLogCallback.calls[0];
    expect(logCall.level, SentryLevel.debug); // trace maps to debug
    expect(logCall.message,
        'test message {"string": "string", "int": 1, "double": 1.23456789, "bool": true, "double_int": 1.0, "nan": NaN, "positive_infinity": Infinity, "negative_infinity": -Infinity}');
    expect(logCall.logger, 'sentry_logger');
  });

  test('bridges SentryLogLevel to SentryLevel correctly', () {
    final mockLogCallback = _MockSdkLogCallback();

    // Set the mock log callback on the fixture hub's options
    fixture.hub.options.log = mockLogCallback.call;
    fixture.hub.options.debug = true;
    fixture.hub.options.diagnosticLevel = SentryLevel.debug;

    final logger = SentryLogger(
      () => fixture.timestamp,
      hub: fixture.hub,
    );

    // Test all log levels to ensure proper bridging
    logger.trace('trace message');
    logger.debug('debug message');
    logger.info('info message');
    logger.warn('warn message');
    logger.error('error message');
    logger.fatal('fatal message');

    // Verify that all calls were made to both the hub and the log callback
    expect(fixture.hub.captureLogCalls.length, 6);
    expect(mockLogCallback.calls.length, 6);

    // Verify the bridging is correct
    expect(mockLogCallback.calls[0].level, SentryLevel.debug); // trace -> debug
    expect(mockLogCallback.calls[1].level, SentryLevel.debug); // debug -> debug
    expect(mockLogCallback.calls[2].level, SentryLevel.info); // info -> info
    expect(
        mockLogCallback.calls[3].level, SentryLevel.warning); // warn -> warning
    expect(mockLogCallback.calls[4].level, SentryLevel.error); // error -> error
    expect(mockLogCallback.calls[5].level, SentryLevel.fatal); // fatal -> fatal
  });

  test('handles NaN and infinite values correctly', () {
    final mockLogCallback = _MockSdkLogCallback();

    // Set the mock log callback on the fixture hub's options
    fixture.hub.options.log = mockLogCallback.call;
    fixture.hub.options.debug = true;
    fixture.hub.options.diagnosticLevel = SentryLevel.debug;

    final logger = SentryLogger(
      () => fixture.timestamp,
      hub: fixture.hub,
    );

    // Test with special double values
    final specialAttributes = <String, SentryAttribute>{
      'nan': SentryAttribute.double(double.nan),
      'positive_infinity': SentryAttribute.double(double.infinity),
      'negative_infinity': SentryAttribute.double(double.negativeInfinity),
    };

    logger.info('special values', attributes: specialAttributes);

    // Verify that both hub.captureLog and our callback were called
    expect(fixture.hub.captureLogCalls.length, 1);
    expect(mockLogCallback.calls.length, 1);

    // Verify the captured log has the right content
    final capturedLog = fixture.hub.captureLogCalls[0].log;
    expect(capturedLog.level, SentryLogLevel.info);
    expect(capturedLog.body, 'special values');
    expect(capturedLog.attributes, specialAttributes);

    // Verify the log callback was called with the right parameters
    final logCall = mockLogCallback.calls[0];
    expect(logCall.level, SentryLevel.info);
    expect(logCall.message,
        'special values {"nan": NaN, "positive_infinity": Infinity, "negative_infinity": -Infinity}');
    expect(logCall.logger, 'sentry_logger');
  });

  // This is mostly an edge case but let's cover it just in case
  test('per-log attributes override fmt template attributes on same key', () {
    final logger = fixture.getSut();

    logger.fmt.info(
      'Hello, %s!',
      ['World'],
      attributes: {
        'sentry.message.template': SentryAttribute.string('OVERRIDE'),
        'sentry.message.parameter.0': SentryAttribute.string('Earth'),
      },
    );

    final attrs = fixture.hub.captureLogCalls[0].log.attributes;
    expect(attrs['sentry.message.template']?.value, 'OVERRIDE');
    expect(attrs['sentry.message.parameter.0']?.value, 'Earth');
  });
}

class Fixture {
  final options = defaultTestOptions();
  final hub = MockHub();
  final timestamp = DateTime.fromMicrosecondsSinceEpoch(0);

  final attributes = <String, SentryAttribute>{
    'string': SentryAttribute.string('string'),
    'int': SentryAttribute.int(1),
    'double': SentryAttribute.double(1.23456789),
    'bool': SentryAttribute.bool(true),
    'double_int': SentryAttribute.double(1.0),
    'nan': SentryAttribute.double(double.nan),
    'positive_infinity': SentryAttribute.double(double.infinity),
    'negative_infinity': SentryAttribute.double(double.negativeInfinity),
  };

  SentryLogger getSut() {
    return SentryLogger(() => timestamp, hub: hub);
  }
}

/// Simple mock for SdkLogCallback to track calls
class _MockSdkLogCallback {
  final List<_LogCall> calls = [];

  void call(
    SentryLevel level,
    String message, {
    String? logger,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    calls.add(_LogCall(level, message, logger, exception, stackTrace));
  }
}

/// Data class to store log call information
class _LogCall {
  final SentryLevel level;
  final String message;
  final String? logger;
  final Object? exception;
  final StackTrace? stackTrace;

  _LogCall(
      this.level, this.message, this.logger, this.exception, this.stackTrace);
}
