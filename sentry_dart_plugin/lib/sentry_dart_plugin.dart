import 'dart:io';

import 'src/configuration.dart';
import 'src/utils/injector.dart';
import 'src/utils/log.dart';

class SentryDartPlugin {
  late Configuration _configuration;

  SentryDartPlugin() {
    initInjector();
  }

  Future<void> run(List<String> cliArguments) async {
    _configuration = injector.get<Configuration>();

    await _configuration.getConfigValues(cliArguments);
    _configuration.validateConfigValues();

    if (_configuration.uploadNativeSymbols) {
      _executeCliForDebugSymbols();
    } else {
      Log.info('uploadNativeSymbols is disabled.');
    }

    if (_configuration.uploadSourceMaps) {
      _executeCliForSourceMaps();
    } else {
      Log.info('uploadSourceMaps is disabled.');
    }
  }

  void _executeCliForDebugSymbols() {
    const taskName = 'uploading symbols';
    Log.startingTask(taskName);

    List<String> params = [];

    _setTokenAndLog(params);

    params.add('upload-dif');

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

    _addWait(params);

    _executeAndLog('Failed to upload symbols', params);

    Log.taskCompleted(taskName);
  }

  void _executeCliForSourceMaps() {
    const taskName = 'uploading source maps';
    Log.startingTask(taskName);

    List<String> params = [];

    _setTokenAndLog(params);

    params.add('releases');

    List<String> releaseFinalizeParams = [];
    releaseFinalizeParams.addAll(params);

    // create new release
    List<String> releaseNewParams = [];
    releaseNewParams.addAll(params);
    releaseNewParams.add('new');

    final release = _getRelease();
    releaseNewParams.add(release);

    Log.info('releaseNewParams $releaseNewParams');

    _executeAndLog('Failed to create new release', releaseNewParams);

    // upload source maps (js and map)
    List<String> releaseJsFilesParams = [];
    releaseJsFilesParams.addAll(params);

    _addExtensionToParams(['map', 'js'], releaseJsFilesParams, release,
        _configuration.webBuildFilesFolder);

    _addWait(releaseJsFilesParams);

    Log.info('releaseJsFilesParams $releaseJsFilesParams');

    _executeAndLog('Failed to upload source maps', releaseJsFilesParams);

    // upload source maps (dart)
    List<String> releaseDartFilesParams = [];
    releaseDartFilesParams.addAll(params);

    _addExtensionToParams(['dart'], releaseDartFilesParams, release,
        _configuration.buildFilesFolder);

    _addWait(releaseDartFilesParams);

    Log.info('releaseDartFilesParams $releaseDartFilesParams');

    _executeAndLog('Failed to upload source maps', releaseDartFilesParams);

    // finalize new release
    releaseFinalizeParams.add('finalize');
    releaseFinalizeParams.add(release);

    Log.info('releaseFinalizeParams $releaseFinalizeParams');

    _executeAndLog('Failed to create new release', releaseFinalizeParams);

    Log.taskCompleted(taskName);
  }

  void _setTokenAndLog(List<String> params) {
    if (_configuration.authToken != null) {
      params.add('--auth-token');
      params.add(_configuration.authToken!);
    }

    if (_configuration.logLevel != null) {
      params.add('--log-level');
      params.add(_configuration.logLevel!);
    }
  }

  void _executeAndLog(String errorMessage, List<String> params) {
    ProcessResult? processResult;
    try {
      processResult = Process.runSync(_configuration.cliPath!, params);
    } catch (exception) {
      Log.error('$errorMessage: \n$exception');
    }
    if (processResult != null) {
      Log.processResult(processResult);
    }
  }

  void _addExtensionToParams(
      List<String> exts, List<String> params, String version, String folder) {
    params.add('files');
    params.add(version);
    params.add('upload-sourcemaps');
    params.add(folder);

    for (final ext in exts) {
      params.add('--ext');
      params.add(ext);
    }

    // TODO: add support to custom dist
    if (version.contains('+')) {
      params.add('--dist');
      final values = version.split('+');
      params.add(values.last);
    }
  }

  String _getRelease() {
    return '${_configuration.name}@${_configuration.version}';
  }

  void _addWait(List<String> params) {
    if (_configuration.wait) {
      params.add('--wait');
    }
  }
}
