import 'package:meta/meta.dart';

import 'access_aware_map.dart';
import '../utils/type_safe_map_access.dart';

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

  @Deprecated('Assign values directly to the instance.')
  SentryTransactionInfo copyWith({
    String? source,
  }) {
    return SentryTransactionInfo(
      source ?? this.source,
      unknown: unknown,
    );
  }

  factory SentryTransactionInfo.fromJson(Map<String, dynamic> data) {
    final json = AccessAwareMap(data);
    return SentryTransactionInfo(
      json.getValueOrNull('source')!,
      unknown: json.notAccessed(),
    );
  }
}
