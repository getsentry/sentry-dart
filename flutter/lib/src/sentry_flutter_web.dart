import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// A web implementation of the SentryFlutter plugin.
class SentryFlutterWeb {
  static void registerWith(Registrar registrar) {
    final channel = MethodChannel(
      'sentry_flutter',
      const StandardMethodCodec(),
      registrar,
    );

    final pluginInstance = SentryFlutterWeb();
    channel.setMethodCallHandler(pluginInstance.handleMethodCall);
  }

  /// Handles method calls over the MethodChannel of this plugin.
  /// Note: Check the "federated" architecture for a new way of doing this:
  /// https://flutter.dev/go/federated-plugins
  Future<dynamic> handleMethodCall(MethodCall call) async {
    return '';
  }
}
