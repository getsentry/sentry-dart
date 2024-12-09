import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LaunchArgs {
  static const MethodChannel _channel = MethodChannel('launchargs');

  /// Returns the list of command line arguments that were passed to the
  /// application at start.  This only supports Android and iOS currently.  All
  /// other platforms will result in an empty list being returned.
  static Future<List<String>> get args async {
    var args = <String>[];
    try {
      if (!kIsWeb) {
        if (Platform.isAndroid || Platform.isIOS) {
          args = List<String>.from(await _channel
              .invokeMethod('args'));
        }
      }
    } catch (e, stackTrace) {
      // no-op
    }
    return args;
  }
}
