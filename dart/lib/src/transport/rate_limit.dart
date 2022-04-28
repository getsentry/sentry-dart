import 'data_category.dart';

/// `RateLimit` containing limited `DataCategory` and duration in milliseconds.
class RateLimit {
  RateLimit(this.category, this.duration);

  final DataCategory category;
  final Duration duration;
}
