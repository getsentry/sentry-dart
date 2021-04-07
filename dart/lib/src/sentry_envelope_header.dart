import 'protocol/sentry_id.dart';
import 'protocol/sdk_version.dart';

class SentryEnvelopeHeader {
  SentryEnvelopeHeader(this.eventId, this.sdkVersion);
  SentryEnvelopeHeader.newEventId()
      : eventId = SentryId.newId(),
        sdkVersion = null;

  final SentryId? eventId;
  final SdkVersion? sdkVersion;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    final tempEventId = eventId;
    if (tempEventId != null) {
      json['event_id'] = tempEventId.toString();
    }
    final tempSdkVersion = sdkVersion;
    if (tempSdkVersion != null) {
      json['sdk'] = tempSdkVersion.toJson();
    }
    return json;
  }
}
