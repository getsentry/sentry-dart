import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/cupertino.dart';

import 'sentry_js_binding.dart';

SentryJsBinding createJsBinding() {
  return WebSentryJsBinding();
}

class WebSentryJsBinding implements SentryJsBinding {
  SentryJsClient? _client;

  @override
  void init(Map<String, dynamic> options) {
    if (options['defaultIntegrations'] != null) {
      options['defaultIntegrations'] = options['defaultIntegrations']
          .map((String integration) => _createIntegration(integration));
    }
    _init(options.jsify());
    _client = SentryJsClient();
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
    final sentryProp = _globalThis.getProperty('Sentry'.toJS);
    if (sentryProp != null) {
      _close();
      _globalThis['Sentry'] = null;
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

  Map<String, String>? _cachedFilenameDebugIds;
  Map<String, String>? get cachedFilenameDebugIds => _cachedFilenameDebugIds;
  int? _lastKeysCount;
  Map<String, List<String>>? _parsedStackResults;

  @override
  Map<String, String>? getFilenameToDebugIdMap() {
    // 1) Read the debug-ID table once
    final debugIdMap =
        _globalThis['_sentryDebugIds'].dartify() as Map<dynamic, dynamic>?;
    if (debugIdMap == null) {
      return null;
    }

    final stackParser = _stackParser();
    if (stackParser == null) {
      return null;
    }

    final debugIdKeys = debugIdMap.keys.toList();

    // 2) Fast path: use cached results if available
    if (_cachedFilenameDebugIds != null &&
        debugIdKeys.length == _lastKeysCount) {
      // Return a copy
      return Map.unmodifiable(_cachedFilenameDebugIds!);
    }
    _lastKeysCount = debugIdKeys.length;

    // 3) Build a map of filename -> debug_id and refresh cache
    final options = _client?.getOptions();
    final Map<String, String> filenameDebugIdMap = {};
    for (final stackKey in debugIdKeys) {
      _parsedStackResults ??= {};

      final String stackKeyStr = stackKey.toString();
      final List<String>? result = _parsedStackResults![stackKeyStr];

      if (result != null) {
        filenameDebugIdMap[result[0]] = result[1];
      } else {
        final parsedStack = stackParser
            .callAsFunction(options, stackKeyStr.toJS)
            .dartify() as List<dynamic>?;

        if (parsedStack == null) continue;

        for (int i = parsedStack.length - 1; i >= 0; i--) {
          final stackFrame = parsedStack[i] as Map<dynamic, dynamic>?;
          final filename = stackFrame?['filename']?.toString();
          final debugId = debugIdMap[stackKeyStr]?.toString();
          if (filename != null && debugId != null) {
            filenameDebugIdMap[filename] = debugId;
            _parsedStackResults![stackKeyStr] = [filename, debugId];
            break;
          }
        }
      }
    }
    _cachedFilenameDebugIds = filenameDebugIdMap;
    return Map.unmodifiable(filenameDebugIdMap);
  }

  JSFunction? _stackParser() {
    final parser = SentryJsClient().getOptions()?['stackParser'];
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

@JS('globalThis')
external JSObject get _globalThis;
