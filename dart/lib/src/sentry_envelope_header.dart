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
    final tempEventId = eventId;
    if (tempEventId != null) {
      serializedMap['event_id'] = tempEventId.toString();
    }
    final tempSdkVersion = sdkVersion;
    if (tempSdkVersion != null) {
      serializedMap['sdk'] = tempSdkVersion.toJson();
    }
    return utf8.encode(jsonEncode(serializedMap));
  }
}
