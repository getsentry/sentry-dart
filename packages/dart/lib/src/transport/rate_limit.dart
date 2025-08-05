import 'data_category.dart';

/// `RateLimit` containing limited `DataCategory` and duration in milliseconds.
class RateLimit {
  RateLimit(this.category, this.duration, {List<String>? namespaces})
      : namespaces = (namespaces?..removeWhere((e) => e.isEmpty)) ?? [];

  final DataCategory category;
  final Duration duration;
  final List<String> namespaces;
}
