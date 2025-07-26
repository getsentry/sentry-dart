import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:meta/meta.dart';

import 'sentry_js_binding.dart';

SentryJsBinding createJsBinding() {
  return WebSentryJsBinding();
}

class WebSentryJsBinding implements SentryJsBinding {
  SentryJsClient? _client;
  JSObject? _options;
  final Map<String, String> _filenameToDebugIds = {};
  final Set<String> _debugIdsWithFilenames = {};

  int _lastKeysCount = 0;

  @visibleForTesting
  Map<String, String>? get filenameToDebugIds => _filenameToDebugIds;

  @override
  void init(Map<String, dynamic> options) {
    if (options['defaultIntegrations'] != null) {
      options['defaultIntegrations'] = options['defaultIntegrations']
          .map((String integration) => _createIntegration(integration));
    }
    _init(options.jsify());
    _client = SentryJsClient();
    _options = _client?.getOptions();
  }

  @override
  void updateSession({int? errors, String? status}) {
    final isolationScope = SentryJsIsolationScope();
    JSObject? currentSession = isolationScope.getSession();
    if (currentSession == null) {
      return;
    }

    if (status != null) {
      currentSession['status'] = status.toJS;
    }

    if (errors != null) {
      currentSession['errors'] = errors.toJS;
    }

    isolationScope.setSession(currentSession);
  }

  JSObject? _createIntegration(String integration) {
    switch (integration) {
      case SentryJsIntegrationName.globalHandlers:
        return _globalHandlersIntegration();
      case SentryJsIntegrationName.dedupe:
        return _dedupeIntegration();
      default:
        return null;
    }
  }

  @override
  void close() {
    final sentryProp = globalThis.getProperty('Sentry'.toJS);
    if (sentryProp != null) {
      _close();
      globalThis['Sentry'] = null;
    }
  }

  @override
  void captureEnvelope(List<Object> envelope) {
    if (_client != null) {
      _client?.sendEnvelope(envelope.jsify());
    }
  }

  @visibleForTesting
  @override
  getJsOptions() {
    return _client?.getOptions().dartify();
  }

  @override
  void startSession({bool ignoreDuration = false}) {
    _startSession({'ignoreDuration': ignoreDuration}.jsify());
  }

  @override
  void captureSession() {
    _captureSession();
  }

  @override
  Map<dynamic, dynamic>? getSession() {
    try {
      return SentryJsIsolationScope().getSession().dartify()
          as Map<dynamic, dynamic>;
    } catch (e) {
      return null;
    }
  }

  @override
  Map<String, String>? getFilenameToDebugIdMap() {
    final options = _options;
    if (options == null) {
      return null;
    }

    final debugIdMap =
        globalThis['_sentryDebugIds'].dartify() as Map<dynamic, dynamic>?;
    if (debugIdMap == null) {
      return null;
    }

    if (debugIdMap.keys.length != _lastKeysCount) {
      _buildFilenameToDebugIdMap(
        debugIdMap,
        options,
      );
      _lastKeysCount = debugIdMap.keys.length;
    }

    return Map.unmodifiable(_filenameToDebugIds);
  }

  void _buildFilenameToDebugIdMap(
    Map<dynamic, dynamic> debugIdMap,
    JSObject options,
  ) {
    final stackParser = _stackParser(options);
    if (stackParser == null) {
      return;
    }

    for (final debugIdMapEntry in debugIdMap.entries) {
      final String stackKeyStr = debugIdMapEntry.key.toString();
      final String debugIdStr = debugIdMapEntry.value.toString();

      final debugIdHasCachedFilename =
          _debugIdsWithFilenames.contains(debugIdStr);

      if (!debugIdHasCachedFilename) {
        final parsedStack = stackParser
            .callAsFunction(options, stackKeyStr.toJS)
            .dartify() as List<dynamic>?;

        if (parsedStack == null) continue;

        for (final stackFrame in parsedStack) {
          final stackFrameMap = stackFrame as Map<dynamic, dynamic>;
          final filename = stackFrameMap['filename']?.toString();
          if (filename != null) {
            _filenameToDebugIds[filename] = debugIdStr;
            _debugIdsWithFilenames.add(debugIdStr);
            break;
          }
        }
      }
    }
  }

  JSFunction? _stackParser(JSObject options) {
    final parser = options['stackParser'];
    if (parser != null && parser.isA<JSFunction>()) {
      return parser as JSFunction;
    }
    return null;
  }
}

@JS('Sentry.init')
external void _init(JSAny? options);

@JS('Sentry.close')
external void _close();

@JS('Sentry.getIsolationScope')
@staticInterop
class SentryJsIsolationScope {
  external factory SentryJsIsolationScope();
}

extension _SentryJsIsolationScopeExtension on SentryJsIsolationScope {
  external JSObject? getSession();
  external void setSession(JSObject session);
}

@JS('Sentry.getClient')
@staticInterop
class SentryJsClient {
  external factory SentryJsClient();
}

extension _SentryJsClientExtension on SentryJsClient {
  external void sendEnvelope(JSAny? envelope);
  external JSObject? getOptions();
}

@JS('Sentry.startSession')
external void _startSession(JSAny? context);

@JS('Sentry.captureSession')
external void _captureSession();

@JS('Sentry.globalHandlersIntegration')
external JSObject _globalHandlersIntegration();

@JS('Sentry.dedupeIntegration')
external JSObject _dedupeIntegration();

@JS('Sentry.browserTracingIntegration')
external JSObject _browserTracingIntegration();

@JS('globalThis')
@internal
external JSObject get globalThis;
