import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'mocks.dart';

void main() {
  const _channel = MethodChannel('sentry_flutter');

  TestWidgetsFlutterBinding.ensureInitialized();

  var called = false;

  final imageList = [
    {
      'code_file': '/apex/com.android.art/javalib/arm64/boot.oat',
      'code_id': '13577ce71153c228ecf0eb73fc39f45010d487f8',
      'image_addr': '0x6f80b000',
      'image_size': 3092480,
      'type': 'elf',
      'debug_id': 'e77c5713-5311-28c2-ecf0-eb73fc39f450',
      'debug_file': 'test'
    }
  ];

  setUp(() {
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {
      called = true;
      return imageList;
    });
  });

  tearDown(() {
    _channel.setMockMethodCallHandler(null);
    called = false;
  });

  test('Native layer is not called as the event is symbolicated', () async {
    final options = SentryOptions()..dsn = fakeDsn;
    final hub = Hub(options);

    loadAndroidImageListIntegration(options, _channel)(hub, options);

    expect(options.eventProcessors.length, 1);

    await hub.captureException(StateError('error'),
        stackTrace: StackTrace.current);

    expect(called, false);
  });

  test('Native layer is not called as the event has no stack traces', () async {
    final options = SentryOptions()..dsn = fakeDsn;
    final hub = Hub(options);

    loadAndroidImageListIntegration(options, _channel)(hub, options);

    await hub.captureException(StateError('error'));

    expect(called, false);
  });

  test('Native layer is called as stack traces are not symbolicated', () async {
    final options = SentryOptions()..dsn = fakeDsn;
    final hub = Hub(options);

    loadAndroidImageListIntegration(options, _channel)(hub, options);

    await hub.captureException(StateError('error'), stackTrace: '''
      warning:  This VM has been configured to produce stack traces that violate the Dart standard.
      ***       *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
      unparsed  pid: 30930, tid: 30990, name 1.ui
      unparsed  build_id: '5346e01103ffeed44e97094ff7bfcc19'
      unparsed  isolate_dso_base: 723d447000, vm_dso_base: 723d447000
      unparsed  isolate_instructions: 723d452000, vm_instructions: 723d449000
      unparsed      #00 abs 000000723d6346d7 virt 00000000001ed6d7 _kDartIsolateSnapshotInstructions+0x1e26d7
      unparsed      #01 abs 000000723d637527 virt 00000000001f0527 _kDartIsolateSnapshotInstructions+0x1e5527
      ''');

    expect(called, true);
  });

  test('Event processor adds image list to the event', () async {
    final options = SentryOptions()..dsn = fakeDsn;
    final hub = Hub(options);

    loadAndroidImageListIntegration(options, _channel)(hub, options);
    final ep = options.eventProcessors.first;
    var event = getEvent();
    event = await ep(event);

    expect(1, event.debugMeta.images.length);
  });

  test('Event processor asserts image list', () async {
    final options = SentryOptions()..dsn = fakeDsn;
    final hub = Hub(options);

    loadAndroidImageListIntegration(options, _channel)(hub, options);
    final ep = options.eventProcessors.first;
    var event = getEvent();
    event = await ep(event);

    final image = event.debugMeta.images.first;

    expect('/apex/com.android.art/javalib/arm64/boot.oat', image.codeFile);
    expect('13577ce71153c228ecf0eb73fc39f45010d487f8', image.codeId);
    expect('0x6f80b000', image.imageAddr);
    expect(3092480, image.imageSize);
    expect('elf', image.type);
    expect('e77c5713-5311-28c2-ecf0-eb73fc39f450', image.debugId);
    expect('test', image.debugFile);
  });
}

SentryEvent getEvent({bool symbolicated = false}) {
  final frame = SentryStackFrame(platform: 'native');
  final st = SentryStackTrace(frames: [frame]);
  final ex = SentryException(
    type: 'type',
    value: 'value',
    stackTrace: st,
  );
  return SentryEvent(exception: ex);
}
