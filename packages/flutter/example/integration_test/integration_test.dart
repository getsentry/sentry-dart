// ignore_for_file: avoid_print
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: unused_local_variable

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter_example/main.dart';

import 'utils.dart';

void main() {
  const org = 'sentry-sdks';
  const slug = 'sentry-flutter';
  const authToken = String.fromEnvironment('SENTRY_AUTH_TOKEN_E2E');
  const fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  IntegrationTestWidgetsFlutterBinding.instance.framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  tearDown(() async {
    await Sentry.close();
  });

  // Using fake DSN for testing purposes.
  Future<void> setupSentryAndApp(WidgetTester tester,
      {String? dsn, BeforeSendCallback? beforeSendCallback}) async {
    await setupSentry(
      () async {
        await tester.pumpWidget(SentryScreenshotWidget(
            child: DefaultAssetBundle(
          bundle: SentryAssetBundle(enableStructuredDataTracing: true),
          child: const MyApp(),
        )));
      },
      dsn ?? fakeDsn,
      isIntegrationTest: true,
      beforeSendCallback: beforeSendCallback,
    );
  }

  // Tests

  testWidgets('setup sentry and render app', (tester) async {
    await setupSentryAndApp(tester);

    // Find any UI element and verify it is present.
    expect(find.text('Open another Scaffold'), findsOneWidget);
  });

  testWidgets('setup sentry and capture event', (tester) async {
    await setupSentryAndApp(tester);

    final event = SentryEvent();
    final sentryId = await Sentry.captureEvent(event);

    expect(sentryId != const SentryId.empty(), true);
  });

  testWidgets('setup sentry and capture exception', (tester) async {
    await setupSentryAndApp(tester);

    try {
      throw SentryException(
        type: 'StarError',
        value: 'I have a bad feeling about this...',
      );
    } catch (exception, stacktrace) {
      final sentryId =
          await Sentry.captureException(exception, stackTrace: stacktrace);

      expect(sentryId != const SentryId.empty(), true);
    }
  });

  testWidgets('setup sentry and capture message', (tester) async {
    await setupSentryAndApp(tester);

    final sentryId = await Sentry.captureMessage('hello world!');

    expect(sentryId != const SentryId.empty(), true);
  });

  testWidgets('setup sentry and capture feedback', (tester) async {
    await setupSentryAndApp(tester);

    final associatedEventId = await Sentry.captureMessage('Associated');
    final feedback = SentryFeedback(
      message: 'message',
      contactEmail: 'john.appleseed@apple.com',
      name: 'John Appleseed',
      associatedEventId: associatedEventId,
    );
    await Sentry.captureFeedback(feedback);
  });

  testWidgets('setup sentry and close', (tester) async {
    await setupSentryAndApp(tester);

    await Sentry.close();
  });

  testWidgets('setup sentry and add breadcrumb', (tester) async {
    await setupSentryAndApp(tester);

    final breadcrumb = Breadcrumb(message: 'fixture-message');
    await Sentry.addBreadcrumb(breadcrumb);
  });

  testWidgets('setup sentry and configure scope', (tester) async {
    await setupSentryAndApp(tester);

    await Sentry.configureScope((scope) async {
      await scope.setContexts('contexts-key', 'contexts-value');
      await scope.removeContexts('contexts-key');

      final user = SentryUser(id: 'fixture-id');
      await scope.setUser(user);
      await scope.setUser(null);

      final breadcrumb = Breadcrumb(message: 'fixture-message');
      await scope.addBreadcrumb(breadcrumb);
      await scope.clearBreadcrumbs();

      // ignore: deprecated_member_use
      await scope.setExtra('extra-key', 'extra-value');
      // ignore: deprecated_member_use
      await scope.removeExtra('extra-key');

      await scope.setTag('tag-key', 'tag-value');
      await scope.removeTag('tag-key');
    });
  });

  testWidgets('setup sentry and start transaction', (tester) async {
    await setupSentryAndApp(tester);

    final transaction = Sentry.startTransaction('transaction', 'test');
    await transaction.finish();
  });

  testWidgets('setup sentry and start transaction with context',
      (tester) async {
    await setupSentryAndApp(tester);

    final context = SentryTransactionContext('transaction', 'test');
    final transaction = Sentry.startTransactionWithContext(context);
    await transaction.finish();
  });

  testWidgets('loads native contexts through loadContexts', (tester) async {
    await restoreFlutterOnErrorAfter(() async {
      await setupSentryAndApp(tester);
    });

    final contexts = await SentryFlutter.native?.loadContexts();

    final appPackageInfo = await PackageInfo.fromPlatform();
    final expectedAppId = Platform.isAndroid
        ? 'io.sentry.samples.flutter'
        : 'io.sentry.flutter.sample';
    final expectedSdkName =
        Platform.isAndroid ? 'maven:sentry-android' : 'cocoapods:sentry-cocoa';
    final expectedVersion = appPackageInfo.version;

    // === BASIC VALIDATION ===
    expect(contexts, isNotNull, reason: 'Loaded contexts are null');
    expect(contexts, isNotEmpty, reason: 'Loaded contexts are empty');
    expect(contexts!.containsKey('contexts'), isTrue,
        reason: 'Contexts section missing');

    final contextData = contexts['contexts'] as Map?;
    expect(contextData, isNotNull, reason: 'Contexts data is null');
    expect(contextData, isNotEmpty, reason: 'Contexts data is empty');

    // === COMMON CONTEXT VALIDATION (All Platforms) ===
    // Check for core context categories
    expect(contextData!.containsKey('app'), isTrue,
        reason: 'App context missing');
    expect(contextData.containsKey('os'), isTrue, reason: 'OS context missing');
    expect(contextData.containsKey('device'), isTrue,
        reason: 'Device context missing');

    // Verify app context has expected fields
    final appContext = contextData['app'] as Map?;
    expect(appContext, isNotNull, reason: 'App context is null');
    expect(appContext!.containsKey('app_name'), isTrue,
        reason: 'App name missing from app context');
    expect(appContext.containsKey('app_version'), isTrue,
        reason: 'App version missing from app context');

    // Verify OS context has expected fields
    final osContext = contextData['os'] as Map?;
    expect(osContext, isNotNull, reason: 'OS context is null');
    expect(osContext!.containsKey('name'), isTrue,
        reason: 'OS name missing from OS context');

    // Verify device context has expected fields
    final deviceContext = contextData['device'] as Map?;
    expect(deviceContext, isNotNull, reason: 'Device context is null');
    expect(deviceContext!.containsKey('model'), isTrue,
        reason: 'Device model missing from device context');

    // Check for other top-level sections that should be present
    expect(contexts.containsKey('user'), isTrue,
        reason: 'User section missing');
    expect(contexts.containsKey('breadcrumbs'), isTrue,
        reason: 'Breadcrumbs section missing');
    // iOS doesn't have tags ootb
    expect(contexts.containsKey('tags'), Platform.isAndroid ? isTrue : isFalse,
        reason: 'Tags section missing');

    // === BREADCRUMBS STRUCTURE (Common) ===
    final breadcrumbs = contexts['breadcrumbs'] as List<dynamic>?;
    expect(breadcrumbs, isNotNull, reason: 'Breadcrumbs data is null');
    expect(breadcrumbs, isA<List>());
    if (breadcrumbs!.isNotEmpty) {
      final firstCrumb = breadcrumbs.first;
      expect(firstCrumb, isA<Map<String, dynamic>>());
      final Map<String, dynamic> crumbMap = firstCrumb as Map<String, dynamic>;
      expect(crumbMap.containsKey('timestamp'), isTrue,
          reason: 'Breadcrumb timestamp missing');
      expect(crumbMap['timestamp'], isA<String>());
      expect(crumbMap.containsKey('category'), isTrue,
          reason: 'Breadcrumb category missing');
      if (crumbMap.containsKey('level')) {
        expect(crumbMap['level'], isA<String>());
      }
      if (crumbMap.containsKey('type')) {
        expect(crumbMap['type'], isA<String>());
      }
      // message or data
      expect(crumbMap.containsKey('message') || crumbMap.containsKey('data'),
          isTrue,
          reason: 'Breadcrumb missing message or data');
    }

    // === PLATFORM-SPECIFIC VALIDATION ===
    if (Platform.isAndroid) {
      // === ANDROID ===
      // package (if available)
      if (contexts.containsKey('package')) {
        final androidPackage = contexts['package'] as Map?;
        expect(androidPackage, isNotNull, reason: 'Package data is null');
        expect(androidPackage!['sdk_name'], equals(expectedSdkName),
            reason: 'Unexpected Android SDK package name');
      }
      // Android-specific validation
      expect(osContext['name'], equals('Android'),
          reason: 'Expected Android OS name');
      expect(deviceContext.containsKey('manufacturer'), isTrue,
          reason: 'Device manufacturer missing from device context');

      // Top-level Android-specific sections
      expect(contexts.containsKey('level'), isTrue,
          reason: 'Top-level level missing');
      final level = contexts['level'];
      expect(level == null || level is String, isTrue,
          reason: 'level must be null or String');

      expect(contexts.containsKey('fingerprint'), isTrue,
          reason: 'Top-level fingerprint missing');
      expect(contexts['fingerprint'], isA<List>());

      expect(contexts.containsKey('extras'), isTrue,
          reason: 'Top-level extras missing');
      expect(contexts['extras'], isA<Map>());

      expect(contexts.containsKey('tags'), isTrue,
          reason: 'Top-level tags missing');
      expect(contexts['tags'], isA<Map>());

      // user id
      final userData = contexts['user'] as Map?;
      expect(userData, isNotNull, reason: 'User data is null');
      expect(userData!.containsKey('id'), isTrue, reason: 'User id missing');
      expect(userData['id'], isA<String>());

      // OS fields
      expect(osContext.containsKey('kernel_version'), isTrue,
          reason: 'OS kernel_version missing');
      expect(osContext['kernel_version'], isA<String>());
      expect(osContext.containsKey('build'), isTrue,
          reason: 'OS build missing');
      expect(osContext['build'], isA<String>());
      expect(osContext.containsKey('rooted'), isTrue,
          reason: 'OS rooted missing');
      expect(osContext['rooted'], isA<bool>());
      expect(osContext.containsKey('version'), isTrue,
          reason: 'OS version missing');
      final iosOsVersion = osContext['version'];
      expect(iosOsVersion is String || iosOsVersion is num, isTrue,
          reason: 'OS version must be String or num');

      // App fields
      expect(appContext.containsKey('app_name'), isTrue,
          reason: 'App app_name missing');
      expect(appContext['app_name'], isA<String>());
      expect(appContext.containsKey('app_build'), isTrue,
          reason: 'App app_build missing');
      final androidAppBuild = appContext['app_build'];
      expect(androidAppBuild is String || androidAppBuild is num, isTrue,
          reason: 'App app_build must be String or num');
      expect(appContext.containsKey('app_version'), isTrue,
          reason: 'App app_version missing');
      expect(appContext['app_version'], isA<String>());
      expect(appContext.containsKey('app_start_time'), isTrue,
          reason: 'App app_start_time missing');
      expect(appContext['app_start_time'], isA<String>());
      final androidAppStart = appContext['app_start_time'] as String?;
      expect(androidAppStart, isNotNull);
      expect(DateTime.tryParse(androidAppStart!), isNotNull,
          reason: 'App app_start_time is not ISO-8601');
      expect(appContext.containsKey('permissions'), isTrue,
          reason: 'App permissions missing');
      final permissions = appContext['permissions'];
      expect(permissions, isA<Map>());
      // Validate permissions entries are strings
      final Map permMap = permissions as Map;
      expect(permMap.keys, everyElement(isA<String>()));
      expect(permMap.values, everyElement(isA<String>()));
      expect(appContext.containsKey('app_identifier'), isTrue,
          reason: 'App app_identifier missing');
      expect(appContext['app_identifier'], equals(expectedAppId));
      // App version should match the platform app version
      expect(appContext.containsKey('app_version'), isTrue,
          reason: 'App app_version missing');
      expect(appContext['app_version'], equals(expectedVersion));
      expect(appContext.containsKey('is_split_apks'), isTrue,
          reason: 'App is_split_apks missing');
      expect(appContext['is_split_apks'], isA<bool>());

      // Device fields
      expect(deviceContext.containsKey('processor_count'), isTrue,
          reason: 'Device processor_count missing');
      expect(deviceContext['processor_count'], isA<num>());
      expect(deviceContext.containsKey('screen_width_pixels'), isTrue,
          reason: 'Device screen_width_pixels missing');
      expect(deviceContext['screen_width_pixels'], isA<num>());
      expect(deviceContext.containsKey('timezone'), isTrue,
          reason: 'Device timezone missing');
      expect(deviceContext['timezone'], isA<String>());
      expect(deviceContext.containsKey('low_memory'), isTrue,
          reason: 'Device low_memory missing');
      expect(deviceContext['low_memory'], isA<bool>());
      expect(deviceContext.containsKey('locale'), isTrue,
          reason: 'Device locale missing');
      expect(deviceContext['locale'], isA<String>());
      expect(deviceContext.containsKey('manufacturer'), isTrue,
          reason: 'Device manufacturer missing');
      expect(deviceContext['manufacturer'], isA<String>());
      expect(deviceContext.containsKey('archs'), isTrue,
          reason: 'Device archs missing');
      expect(deviceContext['archs'], isA<List>());
      final archs = deviceContext['archs'] as List<dynamic>;
      if (archs.isNotEmpty) {
        expect(archs.first, isA<String>());
      }
      expect(deviceContext.containsKey('model'), isTrue,
          reason: 'Device model missing');
      expect(deviceContext['model'], isA<String>());
      expect(deviceContext.containsKey('id'), isTrue,
          reason: 'Device id missing');
      expect(deviceContext['id'], isA<String>());
      expect(deviceContext.containsKey('brand'), isTrue,
          reason: 'Device brand missing');
      expect(deviceContext['brand'], isA<String>());
      expect(deviceContext.containsKey('orientation'), isTrue,
          reason: 'Device orientation missing');
      expect(deviceContext['orientation'], isA<String>());
      expect(deviceContext.containsKey('simulator'), isTrue,
          reason: 'Device simulator missing');
      expect(deviceContext['simulator'], isA<bool>());
      expect(deviceContext.containsKey('battery_level'), isTrue,
          reason: 'Device battery_level missing');
      expect(deviceContext['battery_level'], isA<num>());
      expect(deviceContext.containsKey('connection_type'), isTrue,
          reason: 'Device connection_type missing');
      expect(deviceContext['connection_type'], isA<String>());
      expect(deviceContext.containsKey('charging'), isTrue,
          reason: 'Device charging missing');
      expect(deviceContext['charging'], isA<bool>());
      expect(deviceContext.containsKey('free_memory'), isTrue,
          reason: 'Device free_memory missing');
      expect(deviceContext['free_memory'], isA<num>());
      expect(deviceContext.containsKey('model_id'), isTrue,
          reason: 'Device model_id missing');
      expect(deviceContext['model_id'], isA<String>());
      expect(deviceContext.containsKey('chipset'), isTrue,
          reason: 'Device chipset missing');
      expect(deviceContext['chipset'], isA<String>());
      expect(deviceContext.containsKey('screen_dpi'), isTrue,
          reason: 'Device screen_dpi missing');
      expect(deviceContext['screen_dpi'], isA<num>());
      expect(deviceContext.containsKey('memory_size'), isTrue,
          reason: 'Device memory_size missing');
      expect(deviceContext['memory_size'], isA<num>());
      expect(deviceContext.containsKey('battery_temperature'), isTrue,
          reason: 'Device battery_temperature missing');
      expect(deviceContext['battery_temperature'], isA<num>());
      expect(deviceContext.containsKey('free_storage'), isTrue,
          reason: 'Device free_storage missing');
      expect(deviceContext['free_storage'], isA<num>());
      expect(deviceContext.containsKey('screen_height_pixels'), isTrue,
          reason: 'Device screen_height_pixels missing');
      expect(deviceContext['screen_height_pixels'], isA<num>());
      expect(deviceContext.containsKey('boot_time'), isTrue,
          reason: 'Device boot_time missing');
      expect(deviceContext['boot_time'], isA<String>());
      final bootTime = deviceContext['boot_time'] as String?;
      expect(bootTime, isNotNull);
      expect(DateTime.tryParse(bootTime!), isNotNull,
          reason: 'Device boot_time is not ISO-8601');
      expect(deviceContext.containsKey('screen_density'), isTrue,
          reason: 'Device screen_density missing');
      expect(deviceContext['screen_density'], isA<num>());
      expect(deviceContext.containsKey('storage_size'), isTrue,
          reason: 'Device storage_size missing');
      expect(deviceContext['storage_size'], isA<num>());
      expect(deviceContext.containsKey('online'), isTrue,
          reason: 'Device online missing');
      expect(deviceContext['online'], isA<bool>());
      expect(deviceContext.containsKey('family'), isTrue,
          reason: 'Device family missing');
      expect(deviceContext['family'], isA<String>());
      expect(deviceContext.containsKey('processor_frequency'), isTrue,
          reason: 'Device processor_frequency missing');
      expect(deviceContext['processor_frequency'], isA<num>());
    } else if (Platform.isIOS) {
      // === IOS ===
      // iOS-specific validation
      expect(osContext['name'], equals('iOS'), reason: 'Expected iOS OS name');
      // OS fields
      expect(osContext.containsKey('build'), isTrue,
          reason: 'OS build missing');
      expect(osContext['build'], isA<String>());
      expect(osContext.containsKey('rooted'), isTrue,
          reason: 'OS rooted missing');
      expect(osContext['rooted'], isA<bool>());
      expect(osContext.containsKey('kernel_version'), isTrue,
          reason: 'OS kernel_version missing');
      expect(osContext['kernel_version'], isA<String>());
      expect(osContext.containsKey('version'), isTrue,
          reason: 'OS version missing');
      final iosOsVersion = osContext['version'];
      expect(iosOsVersion is String || iosOsVersion is num, isTrue,
          reason: 'OS version must be String or num');

      // Device fields
      expect(deviceContext.containsKey('processor_count'), isTrue,
          reason: 'Device processor_count missing');
      expect(deviceContext['processor_count'], isA<num>());
      expect(deviceContext.containsKey('locale'), isTrue,
          reason: 'Device locale missing');
      expect(deviceContext['locale'], isA<String>());
      expect(deviceContext.containsKey('family'), isTrue,
          reason: 'Device family missing');
      expect(deviceContext['family'], isA<String>());
      expect(deviceContext.containsKey('model'), isTrue,
          reason: 'Device model missing');
      expect(deviceContext['model'], isA<String>());
      expect(deviceContext.containsKey('screen_height_pixels'), isTrue,
          reason: 'Device screen_height_pixels missing');
      expect(deviceContext['screen_height_pixels'], isA<num>());
      expect(deviceContext.containsKey('screen_width_pixels'), isTrue,
          reason: 'Device screen_width_pixels missing');
      expect(deviceContext['screen_width_pixels'], isA<num>());
      expect(deviceContext.containsKey('thermal_state'), isTrue,
          reason: 'Device thermal_state missing');
      expect(deviceContext['thermal_state'], isA<String>());
      expect(deviceContext.containsKey('usable_memory'), isTrue,
          reason: 'Device usable_memory missing');
      expect(deviceContext['usable_memory'], isA<num>());
      expect(deviceContext.containsKey('memory_size'), isTrue,
          reason: 'Device memory_size missing');
      expect(deviceContext['memory_size'], isA<num>());
      expect(deviceContext.containsKey('free_memory'), isTrue,
          reason: 'Device free_memory missing');
      expect(deviceContext['free_memory'], isA<num>());
      expect(deviceContext.containsKey('arch'), isTrue,
          reason: 'Device arch missing');
      expect(deviceContext['arch'], isA<String>());
      expect(deviceContext.containsKey('simulator'), isTrue,
          reason: 'Device simulator missing');
      expect(deviceContext['simulator'], isA<bool>());
      expect(deviceContext.containsKey('model_id'), isTrue,
          reason: 'Device model_id missing');
      expect(deviceContext['model_id'], isA<String>());

      // App fields
      expect(appContext.containsKey('build_type'), isTrue,
          reason: 'App build_type missing');
      expect(appContext['build_type'], isA<String>());
      expect(appContext.containsKey('app_identifier'), isTrue,
          reason: 'App app_identifier missing');
      expect(appContext['app_identifier'], equals(expectedAppId));
      expect(appContext.containsKey('app_build'), isTrue,
          reason: 'App app_build missing');
      final iosAppBuild = appContext['app_build'];
      expect(iosAppBuild is String || iosAppBuild is num, isTrue,
          reason: 'App app_build must be String or num');
      expect(appContext.containsKey('app_start_time'), isTrue,
          reason: 'App app_start_time missing');
      expect(appContext['app_start_time'], isA<String>());
      final appStartTime = appContext['app_start_time'] as String?;
      expect(appStartTime, isNotNull);
      expect(DateTime.tryParse(appStartTime!), isNotNull,
          reason: 'App app_start_time is not ISO-8601');
      // App version should match the platform app version
      expect(appContext.containsKey('app_version'), isTrue,
          reason: 'App app_version missing');
      expect(appContext['app_version'], equals(expectedVersion));
      expect(appContext.containsKey('device_app_hash'), isTrue,
          reason: 'App device_app_hash missing');
      expect(appContext['device_app_hash'], isA<String>());
      expect(appContext.containsKey('app_id'), isTrue,
          reason: 'App app_id missing');
      expect(appContext['app_id'], isA<String>());
      expect(appContext.containsKey('app_memory'), isTrue,
          reason: 'App app_memory missing');
      expect(appContext['app_memory'], isA<num>());

      // Top-level iOS-specific sections
      // integrations
      expect(contexts.containsKey('integrations'), isTrue,
          reason: 'Integrations section missing');
      final integrations = contexts['integrations'];
      expect(integrations, isA<List>());
      expect((integrations as List), isNotEmpty);
      expect(integrations.first, isA<String>());
      final List<dynamic> integrationsList = integrations;
      expect(integrationsList.contains('SentryCrashIntegration'), isTrue,
          reason: 'Critical integration SentryCrashIntegration missing');
      expect(integrationsList.contains('SentryReplayIntegration'), isFalse,
          reason: 'SentryReplayIntegration should not be present');

      // package info
      expect(contexts.containsKey('package'), isTrue,
          reason: 'Package section missing');
      final packageInfo = contexts['package'] as Map?;
      expect(packageInfo, isNotNull, reason: 'Package data is null');
      expect(packageInfo!.containsKey('sdk_name'), isTrue,
          reason: 'Package sdk_name missing');
      expect(packageInfo['sdk_name'], isA<String>());
      expect(packageInfo['sdk_name'], equals(expectedSdkName),
          reason: 'Unexpected iOS SDK package name');
      expect(packageInfo.containsKey('version'), isTrue,
          reason: 'Package version missing');
      expect(packageInfo['version'], isA<String>());

      // user id
      final userData = contexts['user'] as Map?;
      expect(userData, isNotNull, reason: 'User data is null');
      expect(userData!.containsKey('id'), isTrue, reason: 'User id missing');
      expect(userData['id'], isA<String>());
    }
  });

  testWidgets('loads debug images through loadDebugImages', (tester) async {
    await restoreFlutterOnErrorAfter(() async {
      await setupSentryAndApp(tester);
    });

    // By default it should load all debug images
    final allDebugImages = await SentryFlutter.native
        ?.loadDebugImages(SentryStackTrace(frames: const []));
    expect(allDebugImages, isNotNull);
    // Typically loading all images results in a larger numbers
    expect(allDebugImages, isNotNull, reason: 'Loaded debug images are null');
    expect(allDebugImages!.length > 100, isTrue,
        reason:
            'Loaded debug images are less than 100 - received ${allDebugImages.length}');

    // We can take any other random image for testing
    final expectedImage = allDebugImages.first;
    expect(expectedImage.imageAddr, isNotNull);
    final imageAddr =
        int.parse(expectedImage.imageAddr!.replaceAll('0x', ''), radix: 16);

    // Use the base image address and increase by offset
    // so the instructionAddress will be within the range of the image address
    final imageOffset = (expectedImage.imageSize! / 2).toInt();
    final instructionAddr = '0x${(imageAddr + imageOffset).toRadixString(16)}';
    final sentryFrame = SentryStackFrame(instructionAddr: instructionAddr);

    final debugImageByStacktrace = await SentryFlutter.native
        ?.loadDebugImages(SentryStackTrace(frames: [sentryFrame]));
    expect(debugImageByStacktrace!.length, 1);
    expect(debugImageByStacktrace.first.imageAddr, isNotNull);
    expect(debugImageByStacktrace.first.imageAddr, isNotEmpty);
    expect(debugImageByStacktrace.first.imageAddr, expectedImage.imageAddr);
  });

  group('e2e', () {
    var output = find.byKey(const Key('output'));
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    testWidgets('captureException', (tester) async {
      late Uri uri;

      await restoreFlutterOnErrorAfter(() async {
        await setupSentryAndApp(tester,
            dsn: exampleDsn, beforeSendCallback: fixture.beforeSend);

        await tester.tap(find.text('captureException'));
        await tester.pumpAndSettle();

        final text = output.evaluate().single.widget as Text;
        final id = text.data!;

        uri = Uri.parse(
          'https://sentry.io/api/0/projects/$org/$slug/events/$id/',
        );
      });

      expect(authToken, isNotEmpty);

      final event = await fixture.poll(uri, authToken);
      expect(event, isNotNull);

      final sentEvents = fixture.sentEvents
          .where((el) => el!.eventId.toString() == event!['id']);
      expect(
          sentEvents.length, 1); // one button click should only send one error
      final sentEvent = sentEvents.first;

      final tags = event!['tags'] as List<dynamic>;

      print('event id: ${event['id']}');
      print('event title: ${event['title']}');
      expect(sentEvent!.eventId.toString(), event['id']);
      expect('_Exception: Exception: captureException', event['title']);
      expect(sentEvent.release, event['release']['version']);
      expect(
          2,
          (tags.firstWhere((e) => e['value'] == sentEvent.environment) as Map)
              .length);
      expect(sentEvent.fingerprint, event['fingerprint'] ?? []);
      expect(
          2,
          (tags.firstWhere((e) => e['value'] == SentryLevel.error.name) as Map)
              .length);
      expect(sentEvent.logger, event['logger']);

      final dist = tags.firstWhere((element) => element['key'] == 'dist');
      expect('1', dist['value']);

      final environment =
          tags.firstWhere((element) => element['key'] == 'environment');
      expect('integration', environment['value']);
    });
  });
}

class Fixture {
  List<SentryEvent?> sentEvents = [];

  FutureOr<SentryEvent?> beforeSend(SentryEvent event, Hint hint) async {
    sentEvents.add(event);
    return event;
  }

  Future<Map<String, dynamic>?> poll(Uri url, String authToken) async {
    final client = Client();

    const maxRetries = 10;
    const initialDelay = Duration(seconds: 2);
    const delayIncrease = Duration(seconds: 2);

    var retries = 0;
    var delay = initialDelay;

    while (retries < maxRetries) {
      try {
        print('Trying to fetch $url [try $retries/$maxRetries]');
        final response = await client.get(
          url,
          headers: <String, String>{'Authorization': 'Bearer $authToken'},
        );
        print('Response status code: ${response.statusCode}');
        if (response.statusCode == 200) {
          return jsonDecode(utf8.decode(response.bodyBytes));
        } else if (response.statusCode == 401) {
          print('Cannot fetch $url - invalid auth token.');
          break;
        }
      } catch (e) {
        // Do nothing
      } finally {
        retries++;
        await Future.delayed(delay);
        delay += delayIncrease;
      }
    }
    return null;
  }
}
