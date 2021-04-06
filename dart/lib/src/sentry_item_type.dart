enum SentryItemType { event, unknown }

extension SentryItemTypeExtension on SentryItemType {
  static SentryItemType fromStringValue(String stringValue) {
    switch (stringValue) {
      case 'event':
        return SentryItemType.event;
      default:
        return SentryItemType.unknown;
    }
  }

  String toStringValue() {
    switch (this) {
      case SentryItemType.event:
        return 'event';
      case SentryItemType.unknown:
        return '__unknown__';
    }
  }
}
