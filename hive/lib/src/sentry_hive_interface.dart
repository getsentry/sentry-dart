
import 'package:hive/hive.dart';
import 'package:sentry/sentry.dart';

///
abstract class  SentryHiveInterface implements HiveInterface {
  ///
  void setHub(Hub hub);
}
