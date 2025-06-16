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
}

class Fixture {
  final options = defaultTestOptions();
  final hub = MockHub();
  final timestamp = DateTime.fromMicrosecondsSinceEpoch(0);

  final attributes = <String, SentryLogAttribute>{
    'string': SentryLogAttribute.string('string'),
    'int': SentryLogAttribute.int(1),
    'double': SentryLogAttribute.double(1.0),
    'bool': SentryLogAttribute.bool(true),
  };

  SentryLogger getSut() {
    return SentryLogger(() => timestamp, hub: hub);
  }
}
