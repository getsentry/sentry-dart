import 'dart:async';
// backcompatibility for Flutter < 3.3
// ignore: unnecessary_import
import 'dart:typed_data';
// ignore: unnecessary_import
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

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
  SentryAssetBundle({
    Hub? hub,
    AssetBundle? bundle,
    bool enableStructuredDataTracing = true,
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
  Future<ByteData> load(String key) {
    final outerSpan = _hub.getSpan();
    return _wrapLoad(outerSpan, 'load', key, _bundle.load(key));
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    final outerSpan = _hub.getSpan();
    return _wrapLoad(
      outerSpan,
      'loadString',
      key,
      _bundle.loadString(key, cache: cache),
      updateInnerSpan: (innerSpan) => innerSpan?.setData('from-cache', cache),
    );
  }

  @override
  // This is an override on Flutter greater than 3.1
  // ignore: override_on_non_overriding_member
  Future<ImmutableBuffer> loadBuffer(String key) {
    final outerSpan = _hub.getSpan();
    return _wrapLoad(
      outerSpan,
      'loadBuffer',
      key,
      _loadBuffer(key),
      updateInnerSpan: (innerSpan) => innerSpan?.setData('file.path', key),
    );
  }

  @override
  Future<T> loadStructuredData<T>(
      String key, Future<T> Function(String value) parser) {
    if (!_enableStructuredDataTracing) {
      return _bundle.loadStructuredData(key, parser);
    }
    final outerSpan = _hub.getSpan();
    return _wrapLoad(
      outerSpan,
      'loadStructuredData',
      key,
      _bundle.loadStructuredData(
        key,
        (value) => _wrapParser(() => parser(value), key, outerSpan),
      ),
    );
  }

  @override
  // ignore: override_on_non_overriding_member
  Future<T> loadStructuredBinaryData<T>(
      String key, FutureOr<T> Function(ByteData data) parser) {
    if (!_enableStructuredDataTracing) {
      return _loadStructuredBinaryDataWrapper(key, parser);
    }
    final outerSpan = _hub.getSpan();
    return _wrapLoad(
      outerSpan,
      'loadStructuredBinaryData',
      key,
      _loadStructuredBinaryDataWrapper(
        key,
        (value) =>
            _wrapParser(() => Future.value(parser(value)), key, outerSpan),
      ),
    );
  }

  @override
  void evict(String key) => _bundle.evict(key);

  @override
  void clear() => _bundle.clear();

  // Wrappers

  Future<T> _wrapLoad<T>(
      ISentrySpan? outerSpan, String traceName, String key, Future<T> future,
      {void Function(ISentrySpan?)? updateInnerSpan}) {
    final String description;
    if (traceName == 'loadStructuredData' ||
        traceName == 'loadStructuredBinaryData') {
      description = 'AssetBundle.$traceName<$T>: ${_fileName(key)}';
    } else {
      description = 'AssetBundle.$traceName: ${_fileName(key)}';
    }

    final span = outerSpan?.startChild(
      'file.read',
      description: description,
    );
    span?.setData('file.path', key);
    // ignore: invalid_use_of_internal_member
    span?.origin = SentryTraceOrigins.autoFileAssetBundle;

    if (updateInnerSpan != null) {
      updateInnerSpan(span);
    }

    return _wrapWithCompleter(
      action: () => future,
      onSuccess: (data) {
        _setDataLength(data, span);
        span?.status = const SpanStatus.ok();
        span?.finish(); // Do NOT await
      },
      onError: (error, stackTrace) {
        span?.throwable = error;
        span?.status = SpanStatus.internalError();
        span?.finish(); // Do NOT await, as this will lead to flickering.
      },
    );
  }

  Future<T> _wrapParser<T>(
    Future<T> Function() parser,
    String key,
    ISentrySpan? outerSpan,
  ) {
    final span = outerSpan?.startChild(
      'serialize.file.read',
      description: 'parsing "$key" to "$T"',
    );
    // ignore: invalid_use_of_internal_member
    span?.origin = SentryTraceOrigins.autoFileAssetBundle;

    return _wrapWithCompleter(
      action: parser,
      onSuccess: (data) {
        span?.status = const SpanStatus.ok();
        span?.finish(); // Do NOT await
      },
      onError: (error, stackTrace) {
        span?.throwable = error;
        span?.status = SpanStatus.internalError();
        span?.finish(); // Do NOT await, as this will lead to flickering.
      },
    );
  }

  // Helper

  Future<T> _wrapWithCompleter<T>({
    required Future<T> Function() action,
    required void Function(T) onSuccess,
    required void Function(Object, StackTrace) onError,
  }) {
    Completer<T>? completer;
    Future<T>? result;

    action().then((data) {
      onSuccess(data);

      if (completer != null) {
        completer.complete(data);
      } else {
        result = SynchronousFuture<T>(data);
      }
    }).onError((Object error, StackTrace stackTrace) {
      onError(error, stackTrace);
      // SynchronousFuture does not have an error, only completer left.
      completer?.completeError(error, stackTrace);
    });

    if (result != null) {
      return result!;
    }
    completer = Completer<T>();
    return completer.future;
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

  // Helper: Safe method calls for older flutter versions

  Future<ImmutableBuffer> _loadBuffer(String key) {
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

  Future<T> _loadStructuredBinaryDataWrapper<T>(
    String key,
    FutureOr<T> Function(ByteData data) parser,
  ) {
    // The loadStructuredBinaryData method exists as of Flutter greater than 3.8
    // Previous versions don't have it, but later versions do.
    // We can't use `extends` in order to provide this method because this is
    // a wrapper and thus the method call must be forwarded.
    // On Flutter versions <=3.8 we can't forward this call.
    // On later version the call gets correctly forwarded.
    // The error doesn't need to handled since it can't be called on earlier versions,
    // and it's correctly forwarded on later versions.
    return (_bundle as dynamic).loadStructuredBinaryData<T>(key, parser)
        as Future<T>;
  }
}

@internal
extension SentryAssetBundleInternal on SentryAssetBundle {
  /// Returns the wrapped [AssetBundle].
  AssetBundle get bundle => _bundle;
}
