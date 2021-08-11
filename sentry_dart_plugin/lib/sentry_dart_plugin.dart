import 'dart:io';

import 'src/configuration.dart';
import 'src/utils/injector.dart';
import 'src/utils/log.dart';

class SentryDartPlugin {
  static const sentry_cli = 'sentry-cli';

  late Configuration _configuration;

  SentryDartPlugin() {
    initInjector();
  }

  Future<void> run(List<String> cliArguments) async {
    _configuration = injector.get<Configuration>();

    await _configuration.getConfigValues(cliArguments);
    _configuration.validateConfigValues();

    if (_configuration.uploadNativeSymbols) {
      _executeCli();
    } else {
      Log.info('uploadNativeSymbols is disabled.');
    }
  }

  void _executeCli() {
    const taskName = 'uploading symbols';
    Log.startingTask(taskName);

    List<String> params = [];

    if (_configuration.authToken != null) {
      params.add('--auth-token');
      params.add(_configuration.authToken!);
    }

    if (_configuration.logLevel != null) {
      params.add('--log-level');
      params.add(_configuration.logLevel!);
    }

    params.add('upload-dif');

    // TODO: test if the available symbols actually also have the sources
    if (_configuration.includeNativeSources) {
      params.add('--include-sources');
    } else {
      Log.info('includeNativeSources is disabled, not uploading sources.');
    }

    if (_configuration.org != null) {
      params.add('--org');
      params.add(_configuration.org!);
    }

    if (_configuration.project != null) {
      params.add('--project');
      params.add(_configuration.project!);
    }

    params.add(_configuration.buildFilesFolder);

    if (_configuration.wait) {
      params.add('--wait');
    }

    ProcessResult? processResult;
    try {
      processResult = Process.runSync(sentry_cli, params);
    } catch (exception) {
      Log.error('Failed to upload symbols: \n$exception');
    }
    if (processResult != null) {
      Log.processResult(processResult);
    }

    Log.taskCompleted(taskName);
  }
}
