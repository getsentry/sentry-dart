import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:sentry/sentry.dart';

typedef _Parser<T> = Future<T> Function(String value);

/// An [AssetBundle] which creates automatic performance traces for loading
/// assets.
///
/// You can wrap other [AssetBundle]s in it:
/// ```dart
/// SentryAssetBundle(bundle: someOtherAssetBundle)
/// ```
/// If you're not providing any [AssetBundle], it falls back to the [rootBundle].
///
/// If you want to use the [SentryAssetBundle] by default you can achieve this
/// with the following code:
/// ```dart
/// DefaultAssetBundle(
///   bundle: SentryAssetBundle(),
///   child: MaterialApp(
///     home: MyScaffold(),
///   ),
/// );
/// ```
/// [Image.asset], for example, will then use [SentryAssetBundle].
class SentryAssetBundle implements AssetBundle {
  SentryAssetBundle({Hub? hub, AssetBundle? bundle})
      : _hub = hub ?? HubAdapter(),
        _bundle = bundle ?? rootBundle;

  final Hub _hub;
  final AssetBundle _bundle;

  @override
  Future<ByteData> load(String key) async {
    final span = _hub.getSpan()?.startChild(
          'file.read',
          description: 'AssetBundle.load(key=$key)',
        );

    try {
      final data = await _bundle.load(key);
      await span?.finish(status: SpanStatus.ok());
      return data;
    } catch (e) {
      await span?.finish(status: SpanStatus.internalError());
      rethrow;
    }
  }

  /// Does not create a span. Sometimes [CachingAssetBundle] can throw errors
  /// which are outside the current zone. This is not easy to handle and can
  /// result in corrupt spans.
  @override
  Future<T> loadStructuredData<T>(String key, _Parser<T> parser) =>
      _bundle.loadStructuredData(key, parser);

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final span = _hub.getSpan()?.startChild(
          'file.read',
          description: 'AssetBundle.loadString(key=$key, cache=$cache)',
        );

    try {
      final data = await _bundle.loadString(key, cache: cache);
      await span?.finish(status: SpanStatus.ok());
      return data;
    } catch (_) {
      await span?.finish(status: SpanStatus.internalError());
      rethrow;
    }
  }

  @override
  void evict(String key) => _bundle.evict(key);

  @override
  // This is an override on Flutter 2.8 and later
  // ignore: override_on_non_overriding_member
  void clear() {
    try {
      (_bundle as dynamic).clear();
    } on NoSuchMethodError catch (_) {
      // The clear method exists as of Flutter 2.8
      // Previous versions don't have it, but later versions do.
      // We can't use `extends` in order to provide this method because this is
      // a wrapper and thus the method call must be forwarded.
      // On Flutter version before 2.8 we can't forward this call and
      // just catch the error which is thrown. On later version the call gets
      // correctly forwarded.
    }
  }
}
