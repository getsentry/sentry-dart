part of 'sentry_native_java.dart';

PackageInfo? _loadPackageInfo() => using((arena) {
  final context = native.SentryFlutterPlugin.applicationContext
    ?..releasedBy(arena);
  if (context == null) return null;

  final name = context.packageName!..releasedBy(arena);
  final manager = context.packageManager!..releasedBy(arena);
  final info = manager.getPackageInfo$3(name, 0)!..releasedBy(arena);
  final version = info.versionName?..releasedBy(arena);
  // versionCode omits versionCodeMajor on Android 9 and later.
  final versionCode = native.Build$VERSION.SDK_INT >= 28
      ? info.longVersionCode
      : info.versionCode;
  return PackageInfo(
    appName: '',
    packageName: name.toDartString(),
    version: version?.toDartString() ?? '',
    buildNumber: versionCode.toString(),
  );
});
