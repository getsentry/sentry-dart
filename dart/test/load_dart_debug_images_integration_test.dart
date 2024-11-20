@TestOn('vm')
library dart_test;

import 'dart:async';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/load_dart_debug_images_integration.dart';
import 'package:sentry/src/sentry_stack_trace_factory.dart';
import 'package:test/test.dart';

import 'mocks/mock_platform.dart';
import 'mocks/mock_platform_checker.dart';
import 'test_utils.dart';

void main() {
  final platforms = [
    MockPlatform.iOS(),
    MockPlatform.macOS(),
    MockPlatform.android(),
    MockPlatform.windows(),
  ];

  for (final platform in platforms) {
    group('$LoadDartDebugImagesIntegration $platform', () {
      late Fixture fixture;

      setUp(() {
        fixture = Fixture();
        fixture.options.platformChecker =
            MockPlatformChecker(platform: platform);
      });

      test('adds itself to sdk.integrations', () {
        expect(
          fixture.options.sdk.integrations.contains('loadDartImageIntegration'),
          true,
        );
      });

      test('Event processor is added to options', () {
        expect(fixture.options.eventProcessors.length, 1);
        expect(
          fixture.options.eventProcessors.first.runtimeType.toString(),
          'LoadImageIntegrationEventProcessor',
        );
      });

      test(
          'Event processor does not add debug image if symbolication is not needed',
          () async {
        final event = fixture.newEvent(needsSymbolication: false);
        final resultEvent = await fixture.process(event);

        expect(resultEvent, equals(event));
      });

      test('Event processor does not add debug image if stackTrace is null',
          () async {
        final event = fixture.newEvent();
        final resultEvent = await fixture.process(event);

        expect(resultEvent, equals(event));
      });

      test(
          'Event processor does not add debug image if enableDartSymbolication is false',
          () async {
        fixture.options.enableDartSymbolication = false;
        final event = fixture.newEvent();
        final resultEvent = await fixture.process(event);

        expect(resultEvent, equals(event));
      });

      test('Event processor adds debug image when symbolication is needed',
          () async {
        final debugImage = await fixture.parseAndProcess('''
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
build_id: 'b680cb890f9e3c12a24b172d050dec73'
isolate_dso_base: 10000000
    #00 abs 000000723d6346d7 _kDartIsolateSnapshotInstructions+0x1e26d7
''');
        expect(debugImage?.debugId, isNotEmpty);
        expect(debugImage?.imageAddr, equals('0x10000000'));
      });

      test(
          'Event processor does not add debug image on second stack trace without image address',
          () async {
        final debugImage = await fixture.parseAndProcess('''
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
build_id: 'b680cb890f9e3c12a24b172d050dec73'
isolate_dso_base: 10000000
    #00 abs 000000723d6346d7 _kDartIsolateSnapshotInstructions+0x1e26d7
''');
        expect(debugImage?.debugId, isNotEmpty);
        expect(debugImage?.imageAddr, equals('0x10000000'));

        final event = fixture.newEvent(stackTrace: fixture.parse('''
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
    #00 abs 000000723d6346d7 _kDartIsolateSnapshotInstructions+0x1e26d7
'''));
        final resultEvent = await fixture.process(event);
        expect(resultEvent?.debugMeta?.images, isEmpty);
      });

      test('returns null for invalid stack trace', () async {
        final event =
            fixture.newEvent(stackTrace: fixture.parse('Invalid stack trace'));
        final resultEvent = await fixture.process(event);
        expect(resultEvent?.debugMeta?.images, isEmpty);
      });

      test('extracts correct debug ID with short debugId', () async {
        final debugImage = await fixture.parseAndProcess('''
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
build_id: 'b680cb890f9e3c12a24b172d050dec73'
isolate_dso_base: 20000000
    #00 abs 000000723d6346d7 _kDartIsolateSnapshotInstructions+0x1e26d7
''');

        if (platform.isIOS || platform.isMacOS) {
          expect(debugImage?.debugId, 'b680cb89-0f9e-3c12-a24b-172d050dec73');
        } else {
          expect(debugImage?.debugId, '89cb80b6-9e0f-123c-a24b-172d050dec73');
        }
      });

      test('extracts correct debug ID for Android with long debugId', () async {
        final debugImage = await fixture.parseAndProcess('''
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
build_id: 'f1c3bcc0279865fe3058404b2831d9e64135386c'
isolate_dso_base: 30000000
    #00 abs 000000723d6346d7 _kDartIsolateSnapshotInstructions+0x1e26d7
''');

        expect(debugImage?.debugId,
            equals('c0bcc3f1-9827-fe65-3058-404b2831d9e6'));
      }, skip: !platform.isAndroid);

      test('sets correct type based on platform', () async {
        final debugImage = await fixture.parseAndProcess('''
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
build_id: 'b680cb890f9e3c12a24b172d050dec73'
isolate_dso_base: 40000000
    #00 abs 000000723d6346d7 _kDartIsolateSnapshotInstructions+0x1e26d7
''');

        if (platform.isAndroid || platform.isWindows) {
          expect(debugImage?.type, 'elf');
        } else if (platform.isIOS || platform.isMacOS) {
          expect(debugImage?.type, 'macho');
        } else {
          fail('missing case for platform $platform');
        }
      });

      test('sets codeFile based on platform', () async {
        final debugImage = await fixture.parseAndProcess('''
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
build_id: 'b680cb890f9e3c12a24b172d050dec73'
isolate_dso_base: 40000000
    #00 abs 000000723d6346d7 _kDartIsolateSnapshotInstructions+0x1e26d7
''');

        if (platform.isAndroid) {
          expect(debugImage?.codeFile, 'libapp.so');
        } else if (platform.isWindows) {
          expect(debugImage?.codeFile, 'data/app.so');
        } else if (platform.isIOS || platform.isMacOS) {
          expect(debugImage?.codeFile, 'App.Framework/App');
        } else {
          fail('missing case for platform $platform');
        }
      });

      test('debugImage is cached after first extraction', () async {
        final stackTrace = '''
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
build_id: 'b680cb890f9e3c12a24b172d050dec73'
isolate_dso_base: 10000000
    #00 abs 000000723d6346d7 _kDartIsolateSnapshotInstructions+0x1e26d7
''';
        // First extraction
        final debugImage1 = await fixture.parseAndProcess(stackTrace);
        expect(debugImage1, isNotNull);

        // Second extraction
        final debugImage2 = await fixture.parseAndProcess(stackTrace);
        expect(debugImage2, equals(debugImage1));
      });
    });
  }

  test('debug image is null on unsupported platforms', () async {
    final fixture = Fixture()
      ..options.platformChecker =
          MockPlatformChecker(platform: MockPlatform.linux());
    final event = fixture.newEvent(stackTrace: fixture.parse('''
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
build_id: 'b680cb890f9e3c12a24b172d050dec73'
isolate_dso_base: 40000000
    #00 abs 000000723d6346d7 _kDartIsolateSnapshotInstructions+0x1e26d7
'''));
    final resultEvent = await fixture.process(event);
    expect(resultEvent?.debugMeta?.images.length, 0);
  });
}

class Fixture {
  final options = defaultTestOptions();
  late final factory = SentryStackTraceFactory(options);

  Fixture() {
    final integration = LoadDartDebugImagesIntegration();
    integration.call(Hub(options), options);
  }

  SentryStackTrace parse(String stacktrace) => factory.parse(stacktrace);

  SentryEvent newEvent(
      {bool needsSymbolication = true, SentryStackTrace? stackTrace}) {
    stackTrace ??= SentryStackTrace(frames: [
      SentryStackFrame(platform: needsSymbolication ? null : 'dart')
    ]);
    return SentryEvent(
        threads: [SentryThread(stacktrace: stackTrace)],
        debugMeta: DebugMeta());
  }

  FutureOr<SentryEvent?> process(SentryEvent event) =>
      options.eventProcessors.first.apply(event, Hint());

  Future<DebugImage?> parseAndProcess(String stacktrace) async {
    final event = newEvent(stackTrace: parse(stacktrace));
    final resultEvent = await process(event);
    expect(resultEvent?.debugMeta?.images.length, 1);
    return resultEvent?.debugMeta?.images.first;
  }
}
