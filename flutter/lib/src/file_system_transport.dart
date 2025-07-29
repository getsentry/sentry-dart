// backcompatibility for Flutter < 3.3
// ignore: unnecessary_import
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../sentry_flutter.dart';
import 'native/java/sentry_native_java.dart';
import 'native/sentry_native_binding.dart';
import 'native/java/binding.dart' as java;

/// Serializable data structure for envelope serialization in isolate
class _EnvelopeSerializationData {
  final Map<String, dynamic> headerJson;
  final List<_EnvelopeItemData> items;
  final int maxAttachmentSize;
  final bool automatedTestMode;

  const _EnvelopeSerializationData({
    required this.headerJson,
    required this.items,
    required this.maxAttachmentSize,
    required this.automatedTestMode,
  });
}

/// Serializable envelope item data
class _EnvelopeItemData {
  final Map<String, dynamic> headerData;
  final List<int> data;
  final String itemType;

  const _EnvelopeItemData({
    required this.headerData,
    required this.data,
    required this.itemType,
  });
}

/// Serializes envelope data to bytes in an isolate.
/// This function works with serializable data only.
Future<List<int>> _serializeEnvelopeData(
    _EnvelopeSerializationData data) async {
  final result = <int>[];

  // Add header
  result.addAll(utf8.encode(jsonEncode(data.headerJson)));
  final newLineData = utf8.encode('\n');

  // Add each item
  for (final item in data.items) {
    // Skip large attachments (using string literal since constants aren't available in isolate)
    if (item.itemType == 'attachment' &&
        item.data.length > data.maxAttachmentSize) {
      continue;
    }

    result.addAll(newLineData);
    result.addAll(utf8.encode(jsonEncode(item.headerData)));
    result.addAll(newLineData);
    result.addAll(item.data);
  }

  final data2 = Uint8List.fromList(result);
  captureEnvelopeWithJni(data2);

  return result;
}

class FileSystemTransport implements Transport {
  FileSystemTransport(this._native, this._options);

  final SentryNativeBinding _native;
  final SentryFlutterOptions _options;

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    try {
      final stopwatch = Stopwatch()..start();
      // Prepare serializable data for the isolate
      final serializationData = await _prepareSerializationData(envelope);

      // Serialize envelope in a background isolate to avoid blocking the main thread
      final envelopeData = await compute<_EnvelopeSerializationData, List<int>>(
        _serializeEnvelopeData,
        serializationData,
      );
      stopwatch.stop();
      debugPrint(
          'Envelope serialized with compute in ${stopwatch.elapsedMilliseconds}ms');

      final stopwatch2 = Stopwatch()..start();
      final envelopeData2 = <int>[];
      await envelope.envelopeStream(_options).forEach(envelopeData2.addAll);
      stopwatch2.stop();
      debugPrint(
          'Envelope serialized with legacy in ${stopwatch2.elapsedMilliseconds}ms');

      // TODO avoid copy
      // await _native.captureEnvelope(Uint8List.fromList(envelopeData),
      //     envelope.containsUnhandledException);
    } catch (exception, stackTrace) {
      _options.log(
        SentryLevel.error,
        'Failed to save envelope',
        exception: exception,
        stackTrace: stackTrace,
      );
      if (_options.automatedTestMode) {
        rethrow;
      }
      return SentryId.empty();
    }

    return envelope.header.eventId;
  }

  /// Prepares serializable data from the envelope for isolate processing
  Future<_EnvelopeSerializationData> _prepareSerializationData(
      SentryEnvelope envelope) async {
    final items = <_EnvelopeItemData>[];

    for (final item in envelope.items) {
      try {
        final dataFuture = item.dataFactory();
        final data = dataFuture is Future ? await dataFuture : dataFuture;

        items.add(_EnvelopeItemData(
          headerData: await item.header.toJson(data.length),
          data: data,
          itemType: item.header.type,
        ));
      } catch (_) {
        if (_options.automatedTestMode) {
          rethrow;
        }
        // Skip items that fail to serialize
        continue;
      }
    }

    return _EnvelopeSerializationData(
      headerJson: envelope.header.toJson(),
      items: items,
      maxAttachmentSize: _options.maxAttachmentSize,
      automatedTestMode: _options.automatedTestMode,
    );
  }
}
