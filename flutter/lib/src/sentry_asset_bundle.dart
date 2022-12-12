import 'dart:async';
// backcompatibility for Flutter < 3.3
// ignore: unnecessary_import
import 'dart:typed_data';
// ignore: unnecessary_import
import 'dart:ui';

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
///
/// The `enableStructureDataTracing` setting is an experimental feature.
/// Use at your own risk.
class SentryAssetBundle implements AssetBundle {
  SentryAssetBundle({
    Hub? hub,
    AssetBundle? bundle,
    bool enableStructuredDataTracing = false,
  })  : _hub = hub ?? HubAdapter(),
        _bundle = bundle ?? rootBundle,
        _enableStructuredDataTracing = enableStructuredDataTracing {
    // ignore: invalid_use_of_internal_member
    _hub.options.sdk.addIntegration('AssetBundleTracing');
    if (_enableStructuredDataTracing) {
      // ignore: invalid_use_of_internal_member
      _hub.options.sdk.addIntegration('StructuredDataTracing');
    }
  }

  final Hub _hub;
  final AssetBundle _bundle;
  final bool _enableStructuredDataTracing;

  @override
  Future<ByteData> load(String key) async {
    final span = _hub.getSpan()?.startChild(
          'file.read',
          description: 'AssetBundle.load: ${_fileName(key)}',
        );

    span?.setData('file.path', key);

    ByteData? data;
    try {
      data = await _bundle.load(key);
      _setDataLength(data, span);
      span?.status = SpanStatus.ok();
    } catch (exception) {
      span?.throwable = exception;
      span?.status = SpanStatus.internalError();
      rethrow;
    } finally {
      await span?.finish();
    }
    return data;
  }

  @override
  Future<T> loadStructuredData<T>(String key, _Parser<T> parser) {
    if (_enableStructuredDataTracing) {
      return _loadStructuredDataWithTracing(key, parser);
    }
    return _bundle.loadStructuredData(key, parser);
  }

  Future<T> _loadStructuredDataWithTracing<T>(
      String key, _Parser<T> parser) async {
    final span = _hub.getSpan()?.startChild(
          'file.read',
          description: 'AssetBundle.loadStructuredData<$T>: ${_fileName(key)}',
        );
    span?.setData('file.path', key);

    final completer = Completer<T>();

    // This future is intentionally not awaited. Otherwise we deadlock with
    // the completer.
    // ignore: unawaited_futures
    runZonedGuarded(() async {
      final data = await _bundle.loadStructuredData(
        key,
        (value) async => await _wrapParsing(parser, value, key, span),
      );
      span?.status = SpanStatus.ok();
      completer.complete(data);
    }, (exception, stackTrace) {
      completer.completeError(exception, stackTrace);
    });

    T data;
    try {
      data = await completer.future;
      _setDataLength(data, span);
      span?.status = const SpanStatus.ok();
    } catch (e) {
      span?.throwable = e;
      span?.status = const SpanStatus.internalError();
      rethrow;
    } finally {
      await span?.finish();
    }
    return data;
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final span = _hub.getSpan()?.startChild(
          'file.read',
          description: 'AssetBundle.loadString: ${_fileName(key)}',
        );

    span?.setData('file.path', key);
    span?.setData('from-cache', cache);

    String? data;
    try {
      data = await _bundle.loadString(key, cache: cache);
      span?.status = SpanStatus.ok();
    } catch (exception) {
      span?.throwable = exception;
      span?.status = SpanStatus.internalError();
      rethrow;
    } finally {
      await span?.finish();
    }
    return data;
  }

  void _setDataLength(dynamic data, ISentrySpan? span) {
    int? byteLength;
    if (data is List<int>) {
      byteLength = data.length;
    } else if (data is ByteData) {
      byteLength = data.lengthInBytes;
    } else if (data is ImmutableBuffer) {
      byteLength = data.length;
    }
    if (byteLength != null) {
      span?.setData('file.size', byteLength);
    }
  }

  String _fileName(String key) {
    final uri = Uri.tryParse(key);
    if (uri == null) {
      return key;
    }
    return uri.pathSegments.isEmpty ? key : uri.pathSegments.last;
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

  @override
  // This is an override on Flutter greater than 3.1
  // ignore: override_on_non_overriding_member
  Future<ImmutableBuffer> loadBuffer(String key) async {
    final span = _hub.getSpan()?.startChild(
          'file.read',
          description: 'AssetBundle.loadBuffer: ${_fileName(key)}',
        );

    span?.setData('file.path', key);

    ImmutableBuffer data;
    try {
      data = await _loadBuffer(key);
      _setDataLength(data, span);
      span?.status = SpanStatus.ok();
    } catch (exception) {
      span?.throwable = exception;
      span?.status = SpanStatus.internalError();
      rethrow;
    } finally {
      await span?.finish();
    }
    return data;
  }

  Future<ImmutableBuffer> _loadBuffer(String key) async {
    try {
      // ignore: return_of_invalid_type
      return (_bundle as dynamic).loadBuffer(key);
    } on NoSuchMethodError catch (_) {
      // The loadBuffer method exists as of Flutter greater than 3.1
      // Previous versions don't have it, but later versions do.
      // We can't use `extends` in order to provide this method because this is
      // a wrapper and thus the method call must be forwarded.
      // On Flutter versions <=3.1 we can't forward this call and
      // just catch the error which is thrown. On later version the call gets
      // correctly forwarded.
      //
      // In case of a NoSuchMethodError we just return an empty list
      return ImmutableBuffer.fromUint8List(Uint8List.fromList([]));
    }
  }

  static Future<T> _wrapParsing<T>(
    _Parser<T> parser,
    String value,
    String key,
    ISentrySpan? outerSpan,
  ) async {
    final span = outerSpan?.startChild(
      'serialize.file.read',
      description: 'parsing "$key" to "$T"',
    );
    T data;
    try {
      data = await parser(value);
      span?.status = const SpanStatus.ok();
    } catch (e) {
      span?.throwable = e;
      span?.status = const SpanStatus.internalError();
      rethrow;
    } finally {
      await span?.finish();
    }

    return data;
  }
}
