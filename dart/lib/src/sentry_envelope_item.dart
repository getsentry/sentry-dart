import 'dart:convert';

import 'sentry_attachment/sentry_attachment.dart';
import 'sentry_item_type.dart';
import 'protocol/sentry_event.dart';
import 'sentry_envelope_item_header.dart';

/// Item holding header information and JSON encoded data.
class SentryEnvelopeItem {
  SentryEnvelopeItem(this.header, this.dataFactory);

  factory SentryEnvelopeItem.fromAttachment(SentryAttachment attachment) {
    final cachedItem = _CachedItem(() async {
      return await attachment.bytes;
    });

    final getLength = () async => (await cachedItem.getData()).length;

    final header = SentryEnvelopeItemHeader(
      SentryItemType.attachment,
      getLength,
      contentType: attachment.contentType,
      fileName: attachment.filename,
      attachmentType: attachment.attachmentType,
    );
    return SentryEnvelopeItem(header, cachedItem.getData);
  }

  /// Create an [SentryEnvelopeItem] which holds the [SentryEvent] data.
  factory SentryEnvelopeItem.fromEvent(SentryEvent event) {
    final cachedItem = _CachedItem(() async {
      final jsonEncoded = jsonEncode(event.toJson());
      return utf8.encode(jsonEncoded);
    });

    final getLength = () async {
      return (await cachedItem.getData()).length;
    };

    return SentryEnvelopeItem(
      SentryEnvelopeItemHeader(
        SentryItemType.event,
        getLength,
        contentType: 'application/json',
      ),
      cachedItem.getData,
    );
  }

  /// Header with info about type and length of data in bytes.
  final SentryEnvelopeItemHeader header;

  /// Create binary data representation of item data.
  final Future<List<int>> Function() dataFactory;

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
