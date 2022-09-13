import 'package:meta/meta.dart';

@experimental
class SentryBaggage {
  SentryBaggage(this._keyValues);

  final Map<String, String> _keyValues;

  String toHeaderString() {
    final buffer = StringBuffer();
    // var listMemberCount = 0;

    for (final entry in _keyValues.entries) {
      try {
        final key = _urlEncode(entry.key);
        final value = _urlEncode(entry.value);
        final keyValue = '$key=$value,';

        // TODO: size validation
        // final totalLengthIfValueAdded = buffer.length + keyValue.length
        buffer.write(keyValue);
      } catch (exception, _) {
        // encode could throw ArgumentError
      }
    }

    var header = buffer.toString();
    // remove last leading comma
    if (header.isNotEmpty) {
      header = header.substring(0, header.length - 1);
    }

    return header;
  }

  factory SentryBaggage.fromHeaderList(List<String> headerValues) {
    final keyValues = <String, String>{};

    for (final headerValue in headerValues) {
      final keyValuesToAdd = _extractKeyValuesFromBaggageString(headerValue);
      keyValues.addAll(keyValuesToAdd);
    }

    return SentryBaggage(keyValues);
  }

  factory SentryBaggage.fromHeader(String headerValue) {
    final keyValues = <String, String>{};

    final keyValuesToAdd = _extractKeyValuesFromBaggageString(headerValue);
    keyValues.addAll(keyValuesToAdd);

    return SentryBaggage(keyValues);
  }

  static Map<String, String> _extractKeyValuesFromBaggageString(
      String headerValue) {
    final keyValues = <String, String>{};

    final keyValueStrings = headerValue.split(',');

    for (final keyValueString in keyValueStrings) {
      final keyAndValue = keyValueString.split('=');
      if (keyAndValue.length == 2) {
        try {
          final key = _urlDecode(keyAndValue.first.trim());
          final value = _urlDecode(keyAndValue.last.trim());
          keyValues[key] = value;
        } catch (exception, _) {
          // decode could throw ArgumentError
        }
      }
    }

    return keyValues;
  }

  static String _urlDecode(String uri) {
    // TODO: double check decoding
    return Uri.decodeFull(uri);
  }

  String _urlEncode(String uri) {
    // TODO: double check encoding and replacing
    final encoded = Uri.encodeFull(uri);
    return encoded.replaceAll('\\+', '%20');
  }

  String? get(String key) => _keyValues[key];

  void set(String key, String value) {
    _keyValues[key] = value;
  }

  void setTraceId(String value) {
    set('sentry-trace_id', value);
  }

  void setPublicKey(String value) {
    set('sentry-public_key', value);
  }

  void setEnvironment(String value) {
    set('sentry-environment', value);
  }

  void setRelease(String value) {
    set('sentry-release', value);
  }

  void setUserId(String value) {
    set('sentry-user_id', value);
  }

  void setUserSegment(String value) {
    set('sentry-user_segment', value);
  }

  void setTransaction(String value) {
    set('sentry-transaction', value);
  }

  void setSampleRate(String value) {
    set('sentry-sample_rate', value);
  }
}
