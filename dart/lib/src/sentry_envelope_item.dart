import 'dart:convert';

import 'sentry_item_type.dart';
import 'protocol/sentry_event.dart';
import 'sentry_envelope_item_header.dart';

class SentryEnvelopeItem {
  SentryEnvelopeItem(this.header, this.dataFactory);

  final SentryEnvelopeItemHeader header;
  final Future<List<int>> Function() dataFactory;

  factory SentryEnvelopeItem.fromEvent(SentryEvent event) {
    final cachedItem = CachedItem(() async {
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

  Future<List<int>> toEnvelopeItem() async {
    var data = <int>[];
    data.addAll(utf8.encode(jsonEncode(await header.toJson())));
    data.addAll(utf8.encode('\n'));
    data.addAll(await dataFactory());
    return data;
  }
}

class CachedItem {
  CachedItem(this.dataFactory);

  List<int>? data;
  Future<List<int>> Function() dataFactory;

  Future<List<int>> getData() async {
    data ??= await dataFactory();
    return data!;
  }
}
