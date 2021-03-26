import 'protocol/sentry_id.dart';
import 'protocol/sdk_version.dart';

class SentryEnvelopeHeader {
  SentryEnvelopeHeader(this.eventId, this.sdkVersion);

  final SentryId? eventId;
  final SdkVersion? sdkVersion;

  String serialize() {
    return '';
  }
}
