@TestOn('vm')
library flutter_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/load_image_list_integration.dart';

import 'fixture.dart';

void main() {
  group(LoadImageListIntegration, () {
    final imageList = [
      DebugImage.fromJson({
        'code_file': '/apex/com.android.art/javalib/arm64/boot.oat',
        'code_id': '13577ce71153c228ecf0eb73fc39f45010d487f8',
        'image_addr': '0x6f80b000',
        'image_size': 3092480,
        'type': 'elf',
        'debug_id': 'e77c5713-5311-28c2-ecf0-eb73fc39f450',
        'debug_file': 'test'
      })
    ];

    late IntegrationTestFixture<LoadImageListIntegration> fixture;

    setUp(() async {
      fixture = IntegrationTestFixture(LoadImageListIntegration.new);
      when(fixture.binding.loadDebugImages())
          .thenAnswer((_) async => imageList);
      await fixture.registerIntegration();
    });

    test('$LoadImageListIntegration adds itself to sdk.integrations', () async {
      expect(
        fixture.options.sdk.integrations.contains('loadImageListIntegration'),
        true,
      );
    });

    test('Native layer is not called as the event is symbolicated', () async {
      expect(fixture.options.eventProcessors.length, 1);

      await fixture.hub.captureException(StateError('error'),
          stackTrace: StackTrace.current);

      verifyNever(fixture.binding.loadDebugImages());
    });

    test('Native layer is not called if the event has no stack traces',
        () async {
      await fixture.hub.captureException(StateError('error'));

      verifyNever(fixture.binding.loadDebugImages());
    });

    test('Native layer is called because stack traces are not symbolicated',
        () async {
      await fixture.hub.captureException(StateError('error'), stackTrace: '''
      warning:  This VM has been configured to produce stack traces that violate the Dart standard.
      ***       *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
      pid: 30930, tid: 30990, name 1.ui
      build_id: '5346e01103ffeed44e97094ff7bfcc19'
      isolate_dso_base: 723d447000, vm_dso_base: 723d447000
      isolate_instructions: 723d452000, vm_instructions: 723d449000
          #00 abs 000000723d6346d7 virt 00000000001ed6d7 _kDartIsolateSnapshotInstructions+0x1e26d7
          #01 abs 000000723d637527 virt 00000000001f0527 _kDartIsolateSnapshotInstructions+0x1e5527
      ''');

      verify(fixture.binding.loadDebugImages()).called(1);
    });

    test('Event processor adds image list to the event', () async {
      final ep = fixture.options.eventProcessors.first;
      expect(
          ep.runtimeType.toString(), "_LoadImageListIntegrationEventProcessor");
      SentryEvent? event = _getEvent();
      event = await ep.apply(event, Hint());

      expect(1, event!.debugMeta!.images.length);
    });

    test('Event processor asserts image list', () async {
      final ep = fixture.options.eventProcessors.first;
      SentryEvent? event = _getEvent();
      event = await ep.apply(event, Hint());

      final image = event!.debugMeta!.images.first;

      expect('/apex/com.android.art/javalib/arm64/boot.oat', image.codeFile);
      expect('13577ce71153c228ecf0eb73fc39f45010d487f8', image.codeId);
      expect('0x6f80b000', image.imageAddr);
      expect(3092480, image.imageSize);
      expect('elf', image.type);
      expect('e77c5713-5311-28c2-ecf0-eb73fc39f450', image.debugId);
      expect('test', image.debugFile);
    });

    test('Native layer is not called as there is no exceptions', () async {
      expect(fixture.options.eventProcessors.length, 1);

      await fixture.hub.captureMessage('error');
      verifyNever(fixture.binding.loadDebugImages());
    });
  });
}

SentryEvent _getEvent() {
  final frame = SentryStackFrame(platform: 'native');
  final st = SentryStackTrace(frames: [frame]);
  return SentryEvent(threads: [SentryThread(stacktrace: st)]);
}
