import 'dart:io';

import 'package:package_config/package_config.dart';
import 'package:system_info/system_info.dart';
import 'package:yaml/yaml.dart';

import 'utils/extensions.dart';
import 'utils/log.dart';

class Configuration {
  // cannot use ${Directory.current.path}/build since --split-debug-info allows
  // setting a custom path which is a sibling of build
  String buildFilesFolder = '${Directory.current.path}';

  late bool uploadNativeSymbols;
  late bool includeNativeSources;
  late bool wait;
  late String? project;
  late String? org;
  late String? authToken;
  late String? logLevel;
  late String? _assetsFolder;
  late String cliPath;
  String _fileSeparator = Platform.pathSeparator;

  dynamic _getPubspec() {
    var pubspecString = File("pubspec.yaml").readAsStringSync();
    var pubspec = loadYaml(pubspecString);
    return pubspec;
  }

  Future<void> getConfigValues(List<String> arguments) async {
    const taskName = 'reading config values';
    Log.startingTask(taskName);

    await _getAssetsFolderPath();
    _cliSuffix();
    final pubspec = _getPubspec();
    final config = pubspec['sentry_plugin'];

    uploadNativeSymbols = config?['upload_native_symbols'] ?? true;
    includeNativeSources = config?['include_native_sources'] ?? false;

    project = config?['project']?.toString(); // or env. var. SENTRY_PROJECT
    org = config?['org']?.toString(); // or env. var. SENTRY_ORG
    wait = config?['wait'] ?? false;
    authToken =
        config?['auth_token']?.toString(); // or env. var. SENTRY_AUTH_TOKEN
    logLevel =
        config?['log_level']?.toString(); // or env. var. SENTRY_LOG_LEVEL

    Log.taskCompleted(taskName);
  }

  void validateConfigValues() {
    const taskName = 'validating config values';
    Log.startingTask(taskName);

    final environments = Platform.environment;

    if (project.isNull && environments['SENTRY_PROJECT'].isNull) {
      Log.errorAndExit('Project is empty, check \'project\' at pubspec.yaml');
    }
    if (org.isNull && environments['SENTRY_ORG'].isNull) {
      Log.errorAndExit('Organization is empty, check \'org\' at pubspec.yaml');
    }
    if (authToken.isNull && environments['SENTRY_AUTH_TOKEN'].isNull) {
      Log.errorAndExit(
          'Auth Token is empty, check \'auth_token\' at pubspec.yaml');
    }

    try {
      Process.runSync(cliPath, ['help']);
    } catch (exception) {
      Log.errorAndExit(
          'sentry-cli isn\'t\ available, please follow https://docs.sentry.io/product/cli/installation/ \n$exception');
    }

    Log.taskCompleted(taskName);
  }

  /// Get the assets folder path from the .packages file
  Future<void> _getAssetsFolderPath() async {
    var packagesConfig = await loadPackageConfig(File(
        '${Directory.current.path}${_fileSeparator}.dart_tool${_fileSeparator}package_config.json'));

    var package = packagesConfig.packages
        .firstWhere((package) => package.name == "sentry_dart_plugin");
    var path =
        package.packageUriRoot.toString().replaceAll('file://', '') + 'assets';

    _assetsFolder = Uri.decodeFull(path);

    if (_assetsFolder.isNull) {
      Log.errorAndExit('The assets folder isn\'t\ found.');
    }
  }

  void _cliSuffix() {
    if (Platform.isMacOS) {
      setCliPrefix("Darwin-x86_64");
    } else if (Platform.isWindows) {
      setCliPrefix("Windows-i686.exe");
    } else if (Platform.isLinux) {
      final arch = SysInfo.kernelArchitecture;
      if (arch == "amd64") {
        setCliPrefix("Linux-x86_64");
      } else {
        setCliPrefix("Linux-$arch");
      }
    } else {
      cliPath = 'sentry-cli';
    }
  }

  void setCliPrefix(String suffix) {
    cliPath = "$_assetsFolder${_fileSeparator}sentry-cli-$suffix";
  }
}
