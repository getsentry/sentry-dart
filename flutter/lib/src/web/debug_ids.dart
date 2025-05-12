import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/cupertino.dart';

import 'web_sentry_js_binding.dart';

final Map<String, String> _filenameToDebugIds = {};
final Set<String> _debugIdsWithFilenames = {};

int _lastKeysCount = 0;

@visibleForTesting
Map<String, String>? get filenameToDebugIds => _filenameToDebugIds;

/// Returns the cached map if available, otherwise builds the map with the
/// injected debug ids.
Map<String, String>? getOrCreateFilenameToDebugIdMap(JSObject options) {
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
