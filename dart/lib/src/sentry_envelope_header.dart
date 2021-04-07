import 'dart:convert';

import 'protocol/sentry_id.dart';
import 'protocol/sdk_version.dart';

class SentryEnvelopeHeader {
  SentryEnvelopeHeader(this.eventId, this.sdkVersion);
  SentryEnvelopeHeader.newEventId()
      : eventId = SentryId.newId(),
        sdkVersion = null;

  final SentryId? eventId;
  final SdkVersion? sdkVersion;

  Future<List<int>> serialize() async {
    final serializedMap = <String, dynamic>{};
    if (eventId != null) {
      serializedMap['event_id'] = eventId!.toString();
    }
    if (sdkVersion != null) {
      serializedMap['sdk'] = sdkVersion!.toJson();
    }
    return utf8.encode(jsonEncode(serializedMap));
  }
}
