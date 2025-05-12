import 'dart:js_interop';

import 'package:meta/meta.dart';

Map<String, String>? _cachedFilenameDebugIds;
Map<String, String>? get cachedFilenameDebugIds => _cachedFilenameDebugIds;
final Map<String, List<String>> _parsedStackResults = {};
int? _lastKeysCount;

@internal
Map<String, String>? parseFilenameToDebugIdMap(Map<dynamic, dynamic> debugIdMap,
    JSFunction stackParser, JSObject? options) {
  final debugIdKeys = debugIdMap.keys.toList();

  // Fast path: use cached results if available
  if (_cachedFilenameDebugIds != null && debugIdKeys.length == _lastKeysCount) {
    return Map.unmodifiable(_cachedFilenameDebugIds!);
  }
  _lastKeysCount = debugIdKeys.length;

  // Build a map of filename -> debug_id and refresh cache
  final Map<String, String> filenameDebugIdMap = {};
  for (final stackKey in debugIdKeys) {
    final String stackKeyStr = stackKey.toString();
    final List<String>? result = _parsedStackResults[stackKeyStr];

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
          _parsedStackResults[stackKeyStr] = [filename, debugId];
          break;
        }
      }
    }
  }
  _cachedFilenameDebugIds = filenameDebugIdMap;
  return Map.unmodifiable(filenameDebugIdMap);
}
