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
class SentryAssetBundle extends AssetBundle {
  SentryAssetBundle({Hub? hub, AssetBundle? bundle})
      : _hub = hub ?? HubAdapter(),
        _bundle = bundle ?? rootBundle;

  final Hub _hub;
  final AssetBundle _bundle;

  @override
  Future<ByteData> load(String key) async {
    final span =
        _hub.getSpan()?.startChild('SentryAssetBundle.load', description: key);

    try {
      final data = await _bundle.load(key);
      await span?.finish(status: SpanStatus.ok());
      return data;
    } catch (e) {
      await span?.finish(status: SpanStatus.internalError());
      rethrow;
    }
  }

  @override
  Future<T> loadStructuredData<T>(
    String key,
    _Parser<T> parser,
  ) async {
    final span = _hub.getSpan()?.startChild(
          'SentryAssetBundle.loadStructuredData',
          description: key,
        );

    try {
      final data = await _bundle.loadStructuredData(
        key,
        (value) async => await _wrapParsing(parser, value, key, span),
      );
      await span?.finish(status: SpanStatus.ok());
      return data;
    } catch (e) {
      await span?.finish(status: SpanStatus.internalError());
      rethrow;
    }
  }
}

Future<T> _wrapParsing<T>(
  _Parser<T> parser,
  String value,
  String key,
  ISentrySpan? span,
) async {
  final innerSpan = span?.startChild(
    'SentryAssetBundle.parseStructuredData',
    description: key,
  );
  try {
    final parsedData = await parser(value);
    await innerSpan?.finish();

    return parsedData;
  } catch (e) {
    await span?.finish(status: SpanStatus.internalError());
    rethrow;
  }
}
