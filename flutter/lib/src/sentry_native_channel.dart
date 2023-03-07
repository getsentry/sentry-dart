import 'dart:async';

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

import '../sentry_flutter.dart';

/// Provide typed methods to access native layer.
@internal
class SentryNativeChannel {
  SentryNativeChannel(this._channel, this._options);

  final MethodChannel _channel;
  final SentryFlutterOptions _options;

  // TODO Move other native calls here.

  Future<NativeAppStart?> fetchNativeAppStart() async {
    try {
      final json = await _channel
          .invokeMapMethod<String, dynamic>('fetchNativeAppStart');
      return (json != null) ? NativeAppStart.fromJson(json) : null;
    } catch (error, stackTrace) {
      _logError('fetchNativeAppStart', error, stackTrace);
      return null;
    }
  }

  Future<void> setUser(SentryUser? user) async {
    try {
      await _channel.invokeMethod('setUser', {'user': user?.toJson()});
    } catch (error, stackTrace) {
      _logError('setUser', error, stackTrace);
    }
  }

  Future<void> addBreadcrumb(Breadcrumb breadcrumb) async {
    try {
      await _channel
          .invokeMethod('addBreadcrumb', {'breadcrumb': breadcrumb.toJson()});
    } catch (error, stackTrace) {
      _logError('addBreadcrumb', error, stackTrace);
    }
  }

  Future<void> clearBreadcrumbs() async {
    try {
      await _channel.invokeMethod('clearBreadcrumbs');
    } catch (error, stackTrace) {
      _logError('clearBreadcrumbs', error, stackTrace);
    }
  }

  Future<void> setContexts(String key, dynamic value) async {
    try {
      await _channel.invokeMethod('setContexts', {'key': key, 'value': value});
    } catch (error, stackTrace) {
      _logError('setContexts', error, stackTrace);
    }
  }

  Future<void> removeContexts(String key) async {
    try {
      await _channel.invokeMethod('removeContexts', {'key': key});
    } catch (error, stackTrace) {
      _logError('removeContexts', error, stackTrace);
    }
  }

  Future<void> setExtra(String key, dynamic value) async {
    try {
      await _channel.invokeMethod('setExtra', {'key': key, 'value': value});
    } catch (error, stackTrace) {
      _logError('setExtra', error, stackTrace);
    }
  }

  Future<void> removeExtra(String key) async {
    try {
      await _channel.invokeMethod('removeExtra', {'key': key});
    } catch (error, stackTrace) {
      _logError('removeExtra', error, stackTrace);
    }
  }

  Future<void> setTag(String key, dynamic value) async {
    try {
      await _channel.invokeMethod('setTag', {'key': key, 'value': value});
    } catch (error, stackTrace) {
      _logError('setTag', error, stackTrace);
    }
  }

  Future<void> removeTag(String key) async {
    try {
      await _channel.invokeMethod('removeTag', {'key': key});
    } catch (error, stackTrace) {
      _logError('removeTag', error, stackTrace);
    }
  }

  // Helper

  void _logError(String nativeMethodName, Object error, StackTrace stackTrace) {
    _options.logger(
      SentryLevel.error,
      'Native call `$nativeMethodName` failed',
      exception: error,
      stackTrace: stackTrace,
    );
  }
}

class NativeAppStart {
  NativeAppStart(this.appStartTime, this.isColdStart);

  double appStartTime;
  bool isColdStart;

  factory NativeAppStart.fromJson(Map<String, dynamic> json) {
    return NativeAppStart(
      json['appStartTime'] as double,
      json['isColdStart'] as bool,
    );
  }
}

class NativeFrames {
  NativeFrames(this.totalFrames, this.slowFrames, this.frozenFrames);

  int totalFrames;
  int slowFrames;
  int frozenFrames;

  factory NativeFrames.fromJson(Map<String, dynamic> json) {
    return NativeFrames(
      json['totalFrames'] as int,
      json['slowFrames'] as int,
      json['frozenFrames'] as int,
    );
  }
}
