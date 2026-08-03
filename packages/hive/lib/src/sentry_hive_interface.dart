import 'package:hive/hive.dart';
import 'package:sentry/sentry.dart';

/// The main API interface of SentryHive. Available through the `SentryHive`
/// constant.
abstract class SentryHiveInterface implements HiveInterface {
  /// Set the Sentry [Hub]
  void setHub(Hub hub);
}
