import 'dart:convert';

import 'sentry_item_type.dart';
import 'protocol/sentry_event.dart';
import 'sentry_envelope_item_header.dart';

/// Item holding header information and JSON encoded data.
class SentryEnvelopeItem {
  SentryEnvelopeItem(this.header, this.dataFactory);

  /// Header with info about type and length of data in bytes.
  final SentryEnvelopeItemHeader header;

  /// Create binary data representation of item data.
  final Future<List<int>> Function() dataFactory;

  /// Create an `SentryEnvelopeItem` which holds the `SentyEvent` data.
  factory SentryEnvelopeItem.fromEvent(SentryEvent event) {
    final cachedItem = _CachedItem(() async {
      final jsonEncoded = jsonEncode(event.toJson());
      return utf8.encode(jsonEncoded);
    });

    final getLength = () async {
      return (await cachedItem.getData()).length;
    };

    return SentryEnvelopeItem(
        SentryEnvelopeItemHeader(SentryItemType.event, getLength,
            contentType: 'application/json'),
        cachedItem.getData);
  }

  /// Stream binary data of `Envelope` item.
  Stream<List<int>> envelopeItemStream() async* {
    yield utf8.encode(jsonEncode(await header.toJson()));
    yield utf8.encode('\n');
    yield await dataFactory();
  }
}

class _CachedItem {
  _CachedItem(this._dataFactory);

  final Future<List<int>> Function() _dataFactory;
  List<int>? _data;

  Future<List<int>> getData() async {
    _data ??= await _dataFactory();
    return _data!;
  }
}
