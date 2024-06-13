import 'dart:async';

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import 'sentry_native_invoker.dart';

class SentrySafeMethodChannel with SentryNativeSafeInvoker {
  @override
  final SentryFlutterOptions options;

  final MethodChannel _channel;

  SentrySafeMethodChannel(this._channel, this.options);

  @optionalTypeArgs
  Future<T?> invokeMethod<T>(String method, [dynamic args]) =>
      tryCatchAsync(method, () => _channel.invokeMethod<T>(method, args));

  Future<List<T>?> invokeListMethod<T>(String method, [dynamic args]) =>
      tryCatchAsync(method, () => _channel.invokeListMethod(method, args));

  Future<Map<K, V>?> invokeMapMethod<K, V>(String method, [dynamic args]) =>
      tryCatchAsync(method, () => _channel.invokeMapMethod(method, args));
}
