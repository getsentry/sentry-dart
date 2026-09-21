// ignore_for_file: invalid_use_of_internal_member, depend_on_referenced_packages

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jni/jni.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:package_info_plus_platform_interface/package_info_platform_interface.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/java/binding.dart' as native;

import 'utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('$LoadReleaseIntegration', () {
    tearDown(Sentry.close);

    for (final autoInitialize in [false, true]) {
      testWidgets(
        'loads Android release through JNI with autoInitializeNativeSdk=$autoInitialize',
        (tester) async {
          const channel = MethodChannel(
            'dev.fluttercommunity.plus/package_info',
          );
          final reference = await PackageInfoPlatform.instance.getAll();
          // A cached channel result must not hide a regression to the old path.
          PackageInfo.setMockInitialValues(
            appName: 'unexpected',
            packageName: 'unexpected',
            version: '0',
            buildNumber: '0',
            buildSignature: '',
          );
          addTearDown(
            () => PackageInfo.setMockInitialValues(
              appName: reference.appName,
              packageName: reference.packageName,
              version: reference.version,
              buildNumber: reference.buildNumber,
              buildSignature: reference.buildSignature,
            ),
          );
          var channelCalls = 0;
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(channel, (_) async {
            channelCalls++;
            throw PlatformException(code: 'unexpected_metadata_channel');
          });
          addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
          late SentryFlutterOptions initializedOptions;
          await restoreFlutterOnErrorAfter(() async {
            await SentryFlutter.init((options) {
              options.dsn = fakeDsn;
              options.autoInitializeNativeSdk = autoInitialize;
              options.automatedTestMode = true;
              initializedOptions = options;
            });
          });
          expect(channelCalls, 0);
          messenger.setMockMethodCallHandler(channel, null);
          final expectedRelease =
              '${reference.packageName}@${reference.version}+${reference.buildNumber}';
          expect(initializedOptions.release, expectedRelease);
          expect(initializedOptions.dist, reference.buildNumber);
          if (autoInitialize) {
            final nativeMetadata = using((arena) {
              final scopes = native.Sentry.currentScopes..releasedBy(arena);
              final scopesClass = JClass.forName('io/sentry/IScopes')
                ..releasedBy(arena);
              final options =
                  scopesClass
                      .instanceMethodId(
                        'getOptions',
                        '()Lio/sentry/SentryOptions;',
                      )
                      .call(scopes, native.SentryOptions.type, [])
                    ..releasedBy(arena);
              final release = options.release$1?..releasedBy(arena);
              final dist = options.dist?..releasedBy(arena);
              return (release?.toDartString(), dist?.toDartString());
            });
            expect(nativeMetadata, (expectedRelease, reference.buildNumber));
          }
        },
      );
    }
  }, skip: !Platform.isAndroid);
}
