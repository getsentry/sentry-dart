import 'dart:io';

import 'package:process/process.dart';

import 'src/configuration.dart';
import 'src/utils/injector.dart';
import 'src/utils/log.dart';

/// Class responsible to load the configurations and upload the
/// debug symbols and source maps
class SentryDartPlugin {
  late Configuration _configuration;

  /// SentryDartPlugin ctor. that inits the injectors
  SentryDartPlugin() {
    initInjector();
  }

  /// Method responsible to load the configurations and upload the
  /// debug symbols and source maps
  Future<int> run(List<String> cliArguments) async {
    _configuration = injector.get<Configuration>();

    try {
      await _configuration.getConfigValues(cliArguments);
      if (!_configuration.validateConfigValues()) {
        return 1;
      }

      if (_configuration.uploadNativeSymbols) {
        _executeCliForDebugSymbols();
      } else {
        Log.info('uploadNativeSymbols is disabled.');
      }

      _executeNewRelease();

      if (_configuration.uploadSourceMaps) {
        _executeCliForSourceMaps();
      } else {
        Log.info('uploadSourceMaps is disabled.');
      }

      if (_configuration.commits.toLowerCase() != 'false') {
        _executeSetCommits();
      } else {
        Log.info('Commit integration is disabled.');
      }

      _executeFinalizeRelease();
    } on ExitError catch (e) {
      return e.code;
    }
    return 0;
  }

  void _executeCliForDebugSymbols() {
    const taskName = 'uploading debug symbols';
    Log.startingTask(taskName);

    List<String> params = [];

    _setUrlAndTokenAndLog(params);

    params.add('upload-dif');

    _addOrgAndProject(params);

    if (_configuration.includeNativeSources) {
      params.add('--include-sources');
    } else {
      Log.info('includeNativeSources is disabled, not uploading sources.');
    }

    params.add(_configuration.buildFilesFolder);

    _addWait(params);

    _executeAndLog('Failed to upload symbols', params);

    Log.taskCompleted(taskName);
  }

  List<String> _releasesCliParams() {
    final params = <String>[];
    _setUrlAndTokenAndLog(params);
    params.add('releases');
    _addOrgAndProject(params);
    return params;
  }

  void _executeNewRelease() {
    _executeAndLog('Failed to create a new release',
        [..._releasesCliParams(), 'new', _release]);
  }

  void _executeFinalizeRelease() {
    _executeAndLog('Failed to finalize the new release',
        [..._releasesCliParams(), 'finalize', _release]);
  }

  void _executeSetCommits() {
    final params = [
      ..._releasesCliParams(),
      'set-commits',
      _release,
    ];

    if (['auto', 'true', ''].contains(_configuration.commits.toLowerCase())) {
      params.add('--auto');
    } else {
      params.add('--commit');
      params.add(_configuration.commits);
    }

    _executeAndLog('Failed to set commits', params);
  }

  void _executeCliForSourceMaps() {
    const taskName = 'uploading source maps';
    Log.startingTask(taskName);

    List<String> params = _releasesCliParams();

    // upload source maps (js and map)
    List<String> releaseJsFilesParams = [];
    releaseJsFilesParams.addAll(params);

    _addExtensionToParams(['map', 'js'], releaseJsFilesParams, _release,
        _configuration.webBuildFilesFolder);

    _addWait(releaseJsFilesParams);

    _executeAndLog('Failed to upload source maps', releaseJsFilesParams);

    // upload source maps (dart)
    List<String> releaseDartFilesParams = [];
    releaseDartFilesParams.addAll(params);

    _addExtensionToParams(['dart'], releaseDartFilesParams, _release,
        _configuration.buildFilesFolder);

    _addWait(releaseDartFilesParams);

    _executeAndLog('Failed to upload source maps', releaseDartFilesParams);

    Log.taskCompleted(taskName);
  }

  void _setUrlAndTokenAndLog(List<String> params) {
    if (_configuration.url != null) {
      params.add('--url');
      params.add(_configuration.url!);
    }

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
      processResult = injector
          .get<ProcessManager>()
          .runSync([_configuration.cliPath!, ...params]);
    } on Exception catch (exception) {
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

  String get _release => '${_configuration.name}@${_configuration.version}';

  void _addWait(List<String> params) {
    if (_configuration.waitForProcessing) {
      params.add('--wait');
    }
  }

  void _addOrgAndProject(List<String> params) {
    if (_configuration.org != null) {
      params.add('--org');
      params.add(_configuration.org!);
    }

    if (_configuration.project != null) {
      params.add('--project');
      params.add(_configuration.project!);
    }
  }
}
