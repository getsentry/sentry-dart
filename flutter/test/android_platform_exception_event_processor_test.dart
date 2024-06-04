@TestOn('vm')
library flutter_test;
// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/event_processor/android_platform_exception_event_processor.dart';

import 'mocks.dart';

void main() {
  late Fixture fixture;
  setUp(() {
    fixture = Fixture();

    PackageInfo.setMockInitialValues(
      appName: 'Sentry',
      buildNumber: '1',
      buildSignature: '',
      packageName: 'io.sentry.samples',
      version: '1.2.3',
      installerStore: null,
    );
  });

  group(AndroidPlatformExceptionEventProcessor, () {
    test('platform exception with details and stackTrace is correctly parsed',
        () async {
      final platformExceptionEvent = await fixture.processor
          .apply(fixture.eventWithPlatformDetailsAndStackTrace, Hint());

      final exceptions = platformExceptionEvent!.exceptions!;
      expect(exceptions.length, 3);

      final platformException_1 = exceptions[1];

      expect(platformException_1.type, 'IllegalArgumentException');
      expect(
        platformException_1.value,
        "Unsupported value: '[Ljava.lang.StackTraceElement;@ba6feed' of type 'class [Ljava.lang.StackTraceElement;'",
      );
      expect(platformException_1.stackTrace!.frames.length, 18);

      final platformException_2 = exceptions[2];

      expect(platformException_2.type, 'IllegalArgumentException');
      expect(
        platformException_2.value,
        "Unsupported value: '[Ljava.lang.StackTraceElement;@ba6feed' of type 'class [Ljava.lang.StackTraceElement;'",
      );
      expect(platformException_2.stackTrace!.frames.length, 18);
    });

    test('platform exception with details correctly parsed', () async {
      final platformExceptionEvent = await fixture.processor
          .apply(fixture.eventWithPlatformDetails, Hint());

      final exceptions = platformExceptionEvent!.exceptions!;
      expect(exceptions.length, 2);

      final platformException_1 = exceptions[1];

      expect(platformException_1.type, 'Resources\$NotFoundException');
      expect(platformException_1.module, 'android.content.res');
      expect(
        platformException_1.value,
        "Unable to find resource ID #0x7f14000d",
      );
      expect(platformException_1.stackTrace!.frames.length, 19);
    });

    test('platform exception with stackTrace correctly parsed', () async {
      final platformExceptionEvent = await fixture.processor
          .apply(fixture.eventWithPlatformStackTrace, Hint());

      final exceptions = platformExceptionEvent!.exceptions!;
      expect(exceptions.length, 2);

      final platformException_1 = exceptions[1];

      expect(platformException_1.type, 'IllegalArgumentException');
      expect(platformException_1.module, 'java.lang');
      expect(
        platformException_1.value,
        "Not supported, use openfile",
      );
      expect(platformException_1.stackTrace!.frames.length, 22);
    });

    test(
        'Dart thread is current and not crashed if Android exception is present',
        () async {
      final platformExceptionEvent = await fixture.processor
          .apply(fixture.eventWithPlatformDetailsAndStackTrace, Hint());

      final exceptions = platformExceptionEvent!.exceptions!;
      expect(exceptions.length, 3);

      expect(platformExceptionEvent.threads?.first.current, true);
      expect(platformExceptionEvent.threads?.first.crashed, false);
    });

    test('platformexception has Android thread attached', () async {
      final platformExceptionEvent = await fixture.processor
          .apply(fixture.eventWithPlatformDetailsAndStackTrace, Hint());

      final exceptions = platformExceptionEvent!.exceptions!;
      expect(exceptions.length, 3);

      final platformException = exceptions[1];
      final platformThread = platformExceptionEvent.threads?[1];

      expect(platformException.threadId, platformThread?.id);
      expect(platformThread?.current, false);
      expect(platformThread?.crashed, true);
      expect(platformThread?.name, 'Android');
    });

    test('platformexception has no Android thread attached if disabled',
        () async {
      fixture.options.attachThreads = false;
      final threadCount =
          fixture.eventWithPlatformDetailsAndStackTrace.threads?.length;

      final platformExceptionEvent = await fixture.processor
          .apply(fixture.eventWithPlatformDetailsAndStackTrace, Hint());

      final exceptions = platformExceptionEvent!.exceptions!;
      expect(exceptions.length, 3);

      expect(platformExceptionEvent.threads?.length, threadCount);
    });

    test('does nothing if no PlatformException is there', () async {
      final exception = fixture.options.exceptionFactory
          .getSentryException(detailsAndStackTracePlatformException);

      final event = SentryEvent(
        exceptions: [exception],
        throwable: null,
      );

      final platformExceptionEvent =
          await fixture.processor.apply(event, Hint());

      expect(event, platformExceptionEvent);
    });

    test('does nothing if PlatformException has no stackTrace', () async {
      final platformExceptionEvent =
          await fixture.processor.apply(fixture.eventWithPlatformEmpty, Hint());

      expect(fixture.eventWithPlatformEmpty, platformExceptionEvent);
    });
  });
}

class Fixture {
  late AndroidPlatformExceptionEventProcessor processor =
      AndroidPlatformExceptionEventProcessor(options);

  late SentryException withPlatformDetailsAndStackTrace = options
      .exceptionFactory
      .getSentryException(detailsAndStackTracePlatformException)
      .copyWith(threadId: 1);

  late SentryEvent eventWithPlatformDetailsAndStackTrace = SentryEvent(
    exceptions: [withPlatformDetailsAndStackTrace],
    throwable: detailsAndStackTracePlatformException,
    threads: [dartThread],
  );

  late SentryException withPlatformDetails = options.exceptionFactory
      .getSentryException(detailsPlatformException)
      .copyWith(threadId: 1);

  late SentryEvent eventWithPlatformDetails = SentryEvent(
    exceptions: [withPlatformDetails],
    throwable: detailsPlatformException,
    threads: [dartThread],
  );

  late SentryException withPlatformStackTrace = options.exceptionFactory
      .getSentryException(stackTracePlatformException)
      .copyWith(threadId: 1);

  late SentryEvent eventWithPlatformStackTrace = SentryEvent(
    exceptions: [withPlatformDetails],
    throwable: stackTracePlatformException,
    threads: [dartThread],
  );

  late SentryException withPlatformEmpty = options.exceptionFactory
      .getSentryException(emptyPlatformException)
      .copyWith(threadId: 1);

  late SentryEvent eventWithPlatformEmpty = SentryEvent(
    exceptions: [withPlatformEmpty],
    throwable: emptyPlatformException,
    threads: [dartThread],
  );

  late SentryThread dartThread = SentryThread(
    crashed: true,
    current: true,
    id: 1,
    name: 'main',
  );

  SentryFlutterOptions options = SentryFlutterOptions(dsn: fakeDsn)
    ..attachThreads = true;
}

final detailsAndStackTracePlatformException = PlatformException(
  code: 'error',
  message:
      "Unsupported value: '[Ljava.lang.StackTraceElement;@fa902f1' of type 'class [Ljava.lang.StackTraceElement;'",
  details: _jvmStackTrace,
  stacktrace: _jvmStackTrace,
);

const _jvmStackTrace =
    """java.lang.IllegalArgumentException: Unsupported value: '[Ljava.lang.StackTraceElement;@ba6feed' of type 'class [Ljava.lang.StackTraceElement;'
	at io.flutter.plugin.common.StandardMessageCodec.writeValue(StandardMessageCodec.java:292)
	at io.flutter.plugin.common.StandardMethodCodec.encodeSuccessEnvelope(StandardMethodCodec.java:59)
	at io.flutter.plugin.common.MethodChannel\$IncomingMethodCallHandler\$1.success(MethodChannel.java:267)
	at io.sentry.samples.flutter.MainActivity.configureFlutterEngine\$lambda-0(MainActivity.kt:40)
	at io.sentry.samples.flutter.MainActivity.lambda\$TiSaAm1LIEmKLVswI4BlR_5sw5Y(Unknown Source:0)
	at io.sentry.samples.flutter.-\$\$Lambda\$MainActivity\$TiSaAm1LIEmKLVswI4BlR_5sw5Y.onMethodCall(Unknown Source:2)
	at io.flutter.plugin.common.MethodChannel\$IncomingMethodCallHandler.onMessage(MethodChannel.java:262)
	at io.flutter.embedding.engine.dart.DartMessenger.invokeHandler(DartMessenger.java:296)
	at io.flutter.embedding.engine.dart.DartMessenger.lambda\$dispatchMessageToQueue\$0\$DartMessenger(DartMessenger.java:320)
	at io.flutter.embedding.engine.dart.-\$\$Lambda\$DartMessenger\$TsixYUB5E6FpKhMtCSQVHKE89gQ.run(Unknown Source:12)
	at android.os.Handler.handleCallback(Handler.java:938)
	at android.os.Handler.dispatchMessage(Handler.java:99)
	at android.os.Looper.loopOnce(Looper.java:210)
	at android.os.Looper.loop(Looper.java:299)
	at android.app.ActivityThread.main(ActivityThread.java:8138)
	at java.lang.reflect.Method.invoke(Native Method)
	at com.android.internal.os.RuntimeInit\$MethodAndArgsCaller.run(RuntimeInit.java:556)
	at com.android.internal.os.ZygoteInit.main(ZygoteInit.java:1037)""";

final detailsPlatformException = PlatformException(
  code: 'getNotificationChannelsError',
  message: 'Unable to find resource ID #0x7f14000d',
  details:
      """android.content.res.Resources\$NotFoundException: Unable to find resource ID #0x7f14000d
	at android.content.res.ResourcesImpl.getResourceEntryName(ResourcesImpl.java:493)
	at android.content.res.Resources.getResourceEntryName(Resources.java:2441)
	at com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin.getMappedNotificationChannel(FlutterLocalNotificationsPlugin.java:170)
	at com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin.getNotificationChannels(FlutterLocalNotificationsPlugin.java:32)
	at com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin.onMethodCall(FlutterLocalNotificationsPlugin.java:399)
	at be.j\$a.a(MethodChannel.java:18)
	at pd.c.l(DartMessenger.java:19)
	at pd.c.m(DartMessenger.java:42)
	at pd.c.h(Unknown Source:0)
	at pd.b.run(Unknown Source:12)
	at android.os.Handler.handleCallback(Handler.java:966)
	at android.os.Handler.dispatchMessage(Handler.java:110)
	at android.os.Looper.loopOnce(Looper.java:205)
	at android.os.Looper.loop(Looper.java:293)
	at android.app.ActivityThread.loopProcess(ActivityThread.java:9832)
	at android.app.ActivityThread.main(ActivityThread.java:9821)
	at java.lang.reflect.Method.invoke(Native Method)
	at com.android.internal.os.RuntimeInit\$MethodAndArgsCaller.run(RuntimeInit.java:586)
	at com.android.internal.os.ZygoteInit.main(ZygoteInit.java:1201)""",
  stacktrace: null,
);

final stackTracePlatformException = PlatformException(
  code: "error",
  message: "Not supported, use openfile",
  details: null,
  stacktrace: """java.lang.IllegalArgumentException: Not supported, use openfile
	at android.database.DatabaseUtils.readExceptionFromParcel(DatabaseUtils.java:172)
	at android.database.DatabaseUtils.readExceptionWithFileNotFoundExceptionFromParcel(DatabaseUtils.java:153)
	at android.content.ContentProviderProxy.openTypedAssetFile(ContentProviderNative.java:814)
	at android.content.ContentResolver.openTypedAssetFileDescriptor(ContentResolver.java:2043)
	at android.content.ContentResolver.openTypedAssetFileDescriptor(ContentResolver.java:1981)
	at io.flutter.plugin.platform.f.q(PlatformPlugin.java:57)
	at io.flutter.plugin.platform.f.c(PlatformPlugin.java:1)
	at io.flutter.plugin.platform.f\$a.g(PlatformPlugin.java:3)
	at lb.j\$a.onMethodCall(PlatformChannel.java:294)
	at mb.j\$a.a(MethodChannel.java:18)
	at za.c.l(DartMessenger.java:19)
	at za.c.m(DartMessenger.java:41)
	at za.c.i(Unknown Source:0)
	at za.b.run(Unknown Source:12)
	at android.os.Handler.handleCallback(Handler.java:958)
	at android.os.Handler.dispatchMessage(Handler.java:99)
	at android.os.Looper.loopOnce(Looper.java:230)
	at android.os.Looper.loop(Looper.java:319)
	at android.app.ActivityThread.main(ActivityThread.java:8893)
	at java.lang.reflect.Method.invoke(Native Method)
	at com.android.internal.os.RuntimeInit\$MethodAndArgsCaller.run(RuntimeInit.java:608)
	at com.android.internal.os.ZygoteInit.main(ZygoteInit.java:1103)""",
);

final emptyPlatformException = PlatformException(
  code: 'error',
  message:
      "Unsupported value: '[Ljava.lang.StackTraceElement;@fa902f1' of type 'class [Ljava.lang.StackTraceElement;'",
  details: null,
  stacktrace: null,
);
