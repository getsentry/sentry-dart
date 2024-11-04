import 'dart:async';

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import 'sentry_native_invoker.dart';

class SentrySafeMethodChannel with SentryNativeSafeInvoker {
  @override
  final SentryFlutterOptions options;

  final MethodChannel _channel;

  SentrySafeMethodChannel(this.options) : _channel = options.methodChannel;

  void setMethodCallHandler(
          Future<dynamic> Function(MethodCall call)? handler) =>
      _channel.setMethodCallHandler(handler);

  @optionalTypeArgs
  Future<T?> invokeMethod<T>(String method, [dynamic args]) =>
      tryCatchAsync(method, () => _channel.invokeMethod<T>(method, args));

  Future<List<T>?> invokeListMethod<T>(String method, [dynamic args]) =>
      tryCatchAsync(method, () async {
        // Note, we're not using channel.invokeListMethod because it would fail in tests due to the generated mock not doing a cast.
        final result = await _channel.invokeMethod<List<dynamic>>(method, args);
        return result?.cast<T>();
      });

  Future<Map<K, V>?> invokeMapMethod<K, V>(String method, [dynamic args]) =>
      tryCatchAsync(method, () async {
        // Note, we're not using channel.invokeMapMethod because it would fail in tests due to the generated mock not doing a cast.
        final result =
            await _channel.invokeMethod<Map<dynamic, dynamic>>(method, args);
        return result?.cast<K, V>();
      });
}
