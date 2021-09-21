import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Fixture fixture;

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
    fixture = Fixture();
    fixture.channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return imageList;
    });
  });

  tearDown(() {
    fixture.channel.setMockMethodCallHandler(null);
  });

  test('$LoadAndroidImageListIntegration adds itself to sdk.integrations',
      () async {
    final sut = fixture.getSut();

    sut.call(fixture.hub, fixture.options);

    expect(
      fixture.options.sdk.integrations
          .contains('loadAndroidImageListIntegration'),
      true,
    );
  });

  test('Native layer is not called as the event is symbolicated', () async {
    var called = false;

    final sut = fixture.getSut();
    fixture.channel.setMockMethodCallHandler((MethodCall methodCall) async {
      called = true;
      return imageList;
    });

    sut.call(fixture.hub, fixture.options);

    expect(fixture.options.eventProcessors.length, 1);

    await fixture.hub
        .captureException(StateError('error'), stackTrace: StackTrace.current);

    expect(called, false);
  });

  test('Native layer is not called as the event has no stack traces', () async {
    var called = false;

    final sut = fixture.getSut();
    fixture.channel.setMockMethodCallHandler((MethodCall methodCall) async {
      called = true;
      return imageList;
    });

    sut.call(fixture.hub, fixture.options);

    await fixture.hub.captureException(StateError('error'));

    expect(called, false);
  });

  test('Native layer is called as stack traces are not symbolicated', () async {
    var called = false;

    final sut = fixture.getSut();
    fixture.channel.setMockMethodCallHandler((MethodCall methodCall) async {
      called = true;
      return imageList;
    });

    sut.call(fixture.hub, fixture.options);

    await fixture.hub.captureException(StateError('error'), stackTrace: '''
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
    final sut = fixture.getSut();

    sut.call(fixture.hub, fixture.options);

    final ep = fixture.options.eventProcessors.first;
    SentryEvent? event = getEvent();
    event = await ep.apply(event);

    expect(1, event!.debugMeta!.images.length);
  });

  test('Event processor asserts image list', () async {
    final sut = fixture.getSut();

    sut.call(fixture.hub, fixture.options);
    final ep = fixture.options.eventProcessors.first;
    SentryEvent? event = getEvent();
    event = await ep.apply(event);

    final image = event!.debugMeta!.images.first;

    expect('/apex/com.android.art/javalib/arm64/boot.oat', image.codeFile);
    expect('13577ce71153c228ecf0eb73fc39f45010d487f8', image.codeId);
    expect('0x6f80b000', image.imageAddr);
    expect(3092480, image.imageSize);
    expect('elf', image.type);
    expect('e77c5713-5311-28c2-ecf0-eb73fc39f450', image.debugId);
    expect('test', image.debugFile);
  });

  // test('Event processor isnt executed for transaction', () async {
  //   final sut = fixture.getSut();

  //   sut.call(fixture.hub, fixture.options);
  //   final ep = fixture.options.eventProcessors.first;

  //   var tr = SentryTransaction(fixture.tracer);
  //   tr = await ep.apply(tr) as SentryTransaction;

  //   expect(tr.debugMeta, isNull);
  // });
}

SentryEvent getEvent({bool symbolicated = false}) {
  final frame = SentryStackFrame(platform: 'native');
  final st = SentryStackTrace(frames: [frame]);
  final ex = SentryException(
    type: 'type',
    value: 'value',
    stackTrace: st,
  );
  return SentryEvent(exceptions: [ex]);
}

class Fixture {
  // late SentryTransactionContext _context;
  // late SentryTracer tracer;

  Fixture() {
    // _context = SentryTransactionContext(
    //   'name',
    //   'op',
    // );
    hub = Hub(options);
    // tracer = SentryTracer(_context, hub);
  }

  final channel = MethodChannel('sentry_flutter');
  final options = SentryFlutterOptions(dsn: fakeDsn);

  late Hub hub;

  LoadAndroidImageListIntegration getSut() {
    return LoadAndroidImageListIntegration(channel);
  }
}
