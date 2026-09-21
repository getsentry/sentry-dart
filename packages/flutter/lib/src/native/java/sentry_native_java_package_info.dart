part of 'sentry_native_java.dart';

PackageInfo? _loadPackageInfo() => using((arena) {
  final context = native.SentryFlutterPlugin.applicationContext
    ?..releasedBy(arena);
  if (context == null) return null;

  final name = context.packageName!..releasedBy(arena);
  final manager = context.packageManager!..releasedBy(arena);
  final managerClass = JClass.forName('android/content/pm/PackageManager')
    ..releasedBy(arena);
  final infoClass = JClass.forName('android/content/pm/PackageInfo')
    ..releasedBy(arena);
  final info =
      managerClass
          .instanceMethodId(
            'getPackageInfo',
            '(Ljava/lang/String;I)Landroid/content/pm/PackageInfo;',
          )
          .call(manager, JObject.type, [name, JValueInt(0)])
        ..releasedBy(arena);
  final version =
      infoClass
          .instanceFieldId('versionName', 'Ljava/lang/String;')
          .getNullable(info, JString.type)
        ?..releasedBy(arena);
  final buildVersion = JClass.forName(r'android/os/Build$VERSION')
    ..releasedBy(arena);
  final sdkVersion = buildVersion
      .staticFieldId('SDK_INT', 'I')
      .get(buildVersion, jint.type);
  // versionCode omits versionCodeMajor on Android 9 and later.
  final versionCode = sdkVersion >= 28
      ? infoClass
            .instanceMethodId('getLongVersionCode', '()J')
            .call(info, jlong.type, [])
      : infoClass.instanceFieldId('versionCode', 'I').get(info, jint.type);
  final packageName = name.toDartString();
  return PackageInfo(
    appName: '',
    packageName: packageName,
    version: version?.toDartString() ?? '',
    buildNumber: versionCode.toString(),
  );
});
