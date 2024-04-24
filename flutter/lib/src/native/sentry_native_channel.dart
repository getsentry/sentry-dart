import 'dart:async';

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import 'sentry_native.dart';
import 'method_channel_helper.dart';
import 'sentry_native_binding.dart';

/// Provide typed methods to access native layer via MethodChannel.
@internal
class SentryNativeChannel implements SentryNativeBinding {
  SentryNativeChannel(this._channel);

  final MethodChannel _channel;

  // TODO Move other native calls here.

  @override
  Future<NativeAppStart?> fetchNativeAppStart() async {
    final json =
        await _channel.invokeMapMethod<String, dynamic>('fetchNativeAppStart');
    return (json != null) ? NativeAppStart.fromJson(json) : null;
  }

  @override
  Future<int?> fetchEngineReadyEndtime() async {
    return _channel.invokeMethod('fetchEngineReadyEndtime');
  }

  @override
  Future<void> beginNativeFrames() =>
      _channel.invokeMethod('beginNativeFrames');

  @override
  Future<NativeFrames?> endNativeFrames(SentryId id) async {
    final json = await _channel.invokeMapMethod<String, dynamic>(
        'endNativeFrames', {'id': id.toString()});
    return (json != null) ? NativeFrames.fromJson(json) : null;
  }

  @override
  Future<void> setUser(SentryUser? user) async {
    final normalizedUser = user?.copyWith(
      data: MethodChannelHelper.normalizeMap(user.data),
    );
    await _channel.invokeMethod(
      'setUser',
      {'user': normalizedUser?.toJson()},
    );
  }

  @override
  Future<void> addBreadcrumb(Breadcrumb breadcrumb) async {
    final normalizedBreadcrumb = breadcrumb.copyWith(
      data: MethodChannelHelper.normalizeMap(breadcrumb.data),
    );
    await _channel.invokeMethod(
      'addBreadcrumb',
      {'breadcrumb': normalizedBreadcrumb.toJson()},
    );
  }

  @override
  Future<void> clearBreadcrumbs() => _channel.invokeMethod('clearBreadcrumbs');

  @override
  Future<void> setContexts(String key, dynamic value) => _channel.invokeMethod(
        'setContexts',
        {'key': key, 'value': MethodChannelHelper.normalize(value)},
      );

  @override
  Future<void> removeContexts(String key) =>
      _channel.invokeMethod('removeContexts', {'key': key});

  @override
  Future<void> setExtra(String key, dynamic value) => _channel.invokeMethod(
        'setExtra',
        {'key': key, 'value': MethodChannelHelper.normalize(value)},
      );

  @override
  Future<void> removeExtra(String key) =>
      _channel.invokeMethod('removeExtra', {'key': key});

  @override
  Future<void> setTag(String key, String value) =>
      _channel.invokeMethod('setTag', {'key': key, 'value': value});

  @override
  Future<void> removeTag(String key) =>
      _channel.invokeMethod('removeTag', {'key': key});

  @override
  int? startProfiler(SentryId traceId) =>
      throw UnsupportedError("Not supported on this platform");

  @override
  Future<void> discardProfiler(SentryId traceId) =>
      _channel.invokeMethod('discardProfiler', traceId.toString());

  @override
  Future<Map<String, dynamic>?> collectProfile(
          SentryId traceId, int startTimeNs, int endTimeNs) =>
      _channel.invokeMapMethod<String, dynamic>('collectProfile', {
        'traceId': traceId.toString(),
        'startTime': startTimeNs,
        'endTime': endTimeNs,
      });
}
