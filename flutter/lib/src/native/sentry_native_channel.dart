import 'dart:async';

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import 'sentry_native.dart';
import 'method_channel_helper.dart';

/// Provide typed methods to access native layer via MethodChannel.
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

  Future<void> beginNativeFrames() async {
    try {
      await _channel.invokeMethod('beginNativeFrames');
    } catch (error, stackTrace) {
      _logError('beginNativeFrames', error, stackTrace);
    }
  }

  Future<NativeFrames?> endNativeFrames(SentryId id) async {
    try {
      final json = await _channel.invokeMapMethod<String, dynamic>(
          'endNativeFrames', {'id': id.toString()});
      return (json != null) ? NativeFrames.fromJson(json) : null;
    } catch (error, stackTrace) {
      _logError('endNativeFrames', error, stackTrace);
      return null;
    }
  }

  Future<void> setUser(SentryUser? user) async {
    try {
      final normalizedUser = user?.copyWith(
        data: MethodChannelHelper.normalizeMap(user.data),
      );
      await _channel.invokeMethod(
        'setUser',
        {'user': normalizedUser?.toJson()},
      );
    } catch (error, stackTrace) {
      _logError('setUser', error, stackTrace);
    }
  }

  Future<void> addBreadcrumb(Breadcrumb breadcrumb) async {
    try {
      final normalizedBreadcrumb = breadcrumb.copyWith(
        data: MethodChannelHelper.normalizeMap(breadcrumb.data),
      );
      await _channel.invokeMethod(
        'addBreadcrumb',
        {'breadcrumb': normalizedBreadcrumb.toJson()},
      );
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
      final normalizedValue = MethodChannelHelper.normalize(value);
      await _channel.invokeMethod(
        'setContexts',
        {'key': key, 'value': normalizedValue},
      );
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
      final normalizedValue = MethodChannelHelper.normalize(value);
      await _channel.invokeMethod(
        'setExtra',
        {'key': key, 'value': normalizedValue},
      );
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

  Future<void> setTag(String key, String value) async {
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
