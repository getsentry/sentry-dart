import 'package:meta/meta.dart';

@experimental
class SentryBaggage {
  static const String _sampleRateKeyName = 'sentry-sample_rate';
  static const int _maxChars = 8192;
  static const int _maxListMember = 64;

  SentryBaggage(this._keyValues);

  final Map<String, String> _keyValues;

  String toHeaderString() {
    final buffer = StringBuffer();
    var listMemberCount = 0;
    var separator = '';

    for (final entry in _keyValues.entries) {
      if (listMemberCount >= _maxListMember) {
        // log it max list member
        break;
      }
      try {
        final encodedKey = _urlEncode(entry.key);
        final encodedValue = _urlEncode(entry.value);
        final encodedKeyValue = '$separator$encodedKey=$encodedValue';

        final totalLengthIfValueAdded = buffer.length + encodedKeyValue.length;

        if (totalLengthIfValueAdded >= _maxChars) {
          // log it max length
          continue;
        }

        listMemberCount++;
        buffer.write(encodedKeyValue);
        separator = ',';
      } catch (exception, _) {
        // encode could throw ArgumentError
      }
    }

    return buffer.toString();
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
      // TODO: Note, value MAY contain any number of the equal sign (=) characters.
      // Parsers MUST NOT assume that the equal sign is only used to separate key and value.
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
    // return Uri.decodeFull(uri);
    return Uri.decodeComponent(uri);
  }

  String _urlEncode(String uri) {
    return Uri.encodeComponent(uri);
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
    set(_sampleRateKeyName, value);
  }

  double? getSampleRate() {
    final sampleRate = get(_sampleRateKeyName);
    if (sampleRate == null) {
      return null;
    }

    return double.tryParse(sampleRate);
  }
}
