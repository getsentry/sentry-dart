// ignore_for_file: inference_failure_on_function_invocation

@TestOn('vm')
library flutter_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/event_processor/replay_event_processor.dart';
import 'package:sentry_flutter/src/native/factory.dart';
import 'package:sentry_flutter/src/native/sentry_native_binding.dart';
import '../mocks.dart';
import '../sentry_flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (var mockPlatform in [
    MockPlatform.android(),
  ]) {
    group('$SentryNativeBinding ($mockPlatform)', () {
      late SentryNativeBinding sut;
      late NativeChannelFixture native;
      late SentryFlutterOptions options;

      setUp(() {
        options = SentryFlutterOptions(
            dsn: fakeDsn, checker: getPlatformChecker(platform: mockPlatform))
          // ignore: invalid_use_of_internal_member
          ..automatedTestMode = true;

        native = NativeChannelFixture();
        when(native.channel.invokeMethod('initNativeSdk', any))
            .thenAnswer((_) => Future.value());

        sut = createBinding(options, channel: native.channel);
      });

      test('init sets $ReplayEventProcessor when error replay is enabled',
          () async {
        options.experimental.replay.errorSampleRate = 0.1;
        await sut.init(options);

        expect(options.eventProcessors.map((e) => e.runtimeType.toString()),
            contains('$ReplayEventProcessor'));
      });

      test(
          'init does not set $ReplayEventProcessor when error replay is disabled',
          () async {
        await sut.init(options);

        expect(options.eventProcessors.map((e) => e.runtimeType.toString()),
            isNot(contains('$ReplayEventProcessor')));
      });
    });
  }
}
