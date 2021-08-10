import 'dart:io';

import 'package:yaml/yaml.dart';

import '../sentry_dart_plugin.dart';
// import 'utils/extensions.dart';
import 'utils/log.dart';

class Configuration {
  String buildFilesFolder = '${Directory.current.path}/build';

  late bool uploadNativeSymbols;
  late bool includeNativeSources;
  late bool wait;
  late String? project;
  late String? org;
  late String? authToken;
  late String? logLevel;

  dynamic _getPubspec() {
    var pubspecString = File("pubspec.yaml").readAsStringSync();
    var pubspec = loadYaml(pubspecString);
    return pubspec;
  }

  Future<void> getConfigValues(List<String> arguments) async {
    const taskName = 'reading config values';
    Log.startingTask(taskName);

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

    // TODO: check why String.fromEnvironment isnt returning a value, maybe because
    // its another process or something?

    // if (project.isNull || String.fromEnvironment('SENTRY_PROJECT').isEmpty) {
    //   Log.errorAndExit('Project is empty, check \'project\' at pubspec.yaml');
    // }
    // if (org.isNull || org!.isEmpty) {
    //   Log.errorAndExit('Organization is empty, check \'org\' at pubspec.yaml');
    // }
    // if (authToken.isNull || authToken!.isEmpty) {
    //   Log.errorAndExit(
    //       'Auth Token is empty, check \'auth_token\' at pubspec.yaml');
    // }

    // TODO: add sentry-cli to assets
    try {
      Process.runSync(SentryDartPlugin.sentry_cli, ['help']);
    } catch (exception) {
      Log.errorAndExit(
          'sentry-cli isn\'t\ installed, please follow https://docs.sentry.io/product/cli/installation/ \n$exception');
    }

    Log.taskCompleted(taskName);
  }
}
