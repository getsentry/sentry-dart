import 'package:flutter/services.dart';
import 'package:sentry/sentry.dart';

typedef _Parser<T> = Future<T> Function(String value);

/// An [AssetBundle] which creates automatic performance traces for loading
/// assets.
///
/// Example usage:
/// ```dart
/// MaterialApp(
///    home: DefaultAssetBundle(
///      bundle: SentryAssetBundle(),
///      child: const SomeWidget(),
///    ),
/// );
///
/// // then you'll be able to use
/// DefaultAssetBundle.of(context).load('path/to/asset');
/// ```
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
      await span?.finish();
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
      await span?.finish();
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
