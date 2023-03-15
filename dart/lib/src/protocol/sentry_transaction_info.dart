class SentryTransactionInfo {
  SentryTransactionInfo(this.source);

  final String source;

  Map<String, dynamic> toJson() {
    return {
      'source': source,
    };
  }

  SentryTransactionInfo copyWith({
    String? source,
  }) {
    return SentryTransactionInfo(
      source ?? this.source,
    );
  }

  factory SentryTransactionInfo.fromJson(Map<String, dynamic> json) {
    return SentryTransactionInfo(
      json['source'],
    );
  }
}
