import 'package:meta/meta.dart';

import 'access_aware_map.dart';

class SentryTransactionInfo {
  SentryTransactionInfo(this.source, {this.unknown});

  final String source;

  @internal
  final Map<String, dynamic>? unknown;

  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      'source': source,
    };
  }

  factory SentryTransactionInfo.fromJson(Map<String, dynamic> data) {
    final json = AccessAwareMap(data);
    return SentryTransactionInfo(
      json['source'],
      unknown: json.notAccessed(),
    );
  }
}
