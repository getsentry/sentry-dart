import 'package:meta/meta.dart';

import 'unknown.dart';

class SentryTransactionInfo {
  SentryTransactionInfo(this.source, {this.unknown});

  final String source;

  @internal
  final Map<String, dynamic>? unknown;

  Map<String, dynamic> toJson() {
    return {
      'source': source,
      ...?unknown,
    };
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
