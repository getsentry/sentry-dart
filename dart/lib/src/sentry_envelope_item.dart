import 'dart:convert';
import 'protocol.dart';
import 'utils.dart';
import 'sentry_attachment/sentry_attachment.dart';
import 'sentry_item_type.dart';
import 'sentry_envelope_item_header.dart';
import 'sentry_user_feedback.dart';

/// Item holding header information and JSON encoded data.
class SentryEnvelopeItem {
  SentryEnvelopeItem(this.header, this.dataFactory);

  /// Creates an [SentryEnvelopeItem] which sends [SentryTransaction].
  factory SentryEnvelopeItem.fromTransaction(SentryTransaction transaction) {
    final cachedItem = _CachedItem(() async {
      final jsonEncoded = jsonEncode(
        transaction.toJson(),
        toEncodable: jsonSerializationFallback,
      );
      return utf8.encode(jsonEncoded);
    });

    final getLength = () async {
      return (await cachedItem.getData()).length;
    };

    final header = SentryEnvelopeItemHeader(
      SentryItemType.transaction,
      getLength,
      contentType: 'application/json',
    );
    return SentryEnvelopeItem(header, cachedItem.getData);
  }

  factory SentryEnvelopeItem.fromAttachment(SentryAttachment attachment) {
    final cachedItem = _CachedItem(() async => await attachment.bytes);

    final getLength = () async {
      try {
        return (await cachedItem.getData()).length;
      } catch (_) {
        return -1;
      }
    };

    final header = SentryEnvelopeItemHeader(
      SentryItemType.attachment,
      getLength,
      contentType: attachment.contentType,
      fileName: attachment.filename,
      attachmentType: attachment.attachmentType,
    );
    return SentryEnvelopeItem(header, cachedItem.getData);
  }

  /// Create an [SentryEnvelopeItem] which sends [SentryUserFeedback].
  factory SentryEnvelopeItem.fromUserFeedback(SentryUserFeedback feedback) {
    final bytes = _jsonToBytes(feedback.toJson());

    final header = SentryEnvelopeItemHeader(
      SentryItemType.userFeedback,
      () async => bytes.length,
      contentType: 'application/json',
    );
    return SentryEnvelopeItem(header, () async => bytes);
  }

  /// Create an [SentryEnvelopeItem] which holds the [SentryEvent] data.
  factory SentryEnvelopeItem.fromEvent(SentryEvent event) {
    final bytes = _jsonToBytes(event.toJson());

    return SentryEnvelopeItem(
      SentryEnvelopeItemHeader(
        SentryItemType.event,
        () async => bytes.length,
        contentType: 'application/json',
      ),
      () async => bytes,
    );
  }

  /// Header with info about type and length of data in bytes.
  final SentryEnvelopeItemHeader header;

  /// Create binary data representation of item data.
  final Future<List<int>> Function() dataFactory;

  /// Stream binary data of `Envelope` item.
  Future<List<int>> envelopeItemStream() async {
    // Each item needs to be encoded as one unit.
    // Otherwise the header alredy got yielded if the content throws
    // an exception.
    try {
      final itemHeader = utf8.encode(jsonEncode(
        await header.toJson(),
        toEncodable: jsonSerializationFallback,
      ));
      final newLine = utf8.encode('\n');
      final data = await dataFactory();
      return [...itemHeader, ...newLine, ...data];
    } catch (e) {
      return [];
    }
  }

  static List<int> _jsonToBytes(Map<String, dynamic> json) {
    return utf8.encode(
      jsonEncode(
        json,
        toEncodable: jsonSerializationFallback,
      ),
    );
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
