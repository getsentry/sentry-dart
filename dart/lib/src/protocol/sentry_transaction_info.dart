import 'package:meta/meta.dart';

import 'unknown.dart';

class SentryTransactionInfo {
  SentryTransactionInfo(this.source, {this.unknown});

  final String source;

  @internal
  final Map<String, dynamic>? unknown;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'source': source,
    };
    if (unknown != null) {
      json.addAll(unknown ?? {});
    }
    return json;
  }

  SentryTransactionInfo copyWith({
    String? source,
  }) {
    return SentryTransactionInfo(
      source ?? this.source,
      unknown: unknown,
    );
  }

  factory SentryTransactionInfo.fromJson(Map<String, dynamic> json) {
    return SentryTransactionInfo(
      json['source'],
      unknown: unknownFrom(json, {'source'}),
    );
  }
}
