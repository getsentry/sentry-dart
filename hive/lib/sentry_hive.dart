library sentry_hive;

import 'package:meta/meta.dart';
import 'package:hive/hive.dart';
import 'src/sentry_hive_impl.dart';
import 'src/sentry_hive_interface.dart';

export 'src/sentry_hive_interface.dart';
export 'src/sentry_box_collection.dart';

/// Use [SentryHive] constant instead of [Hive] to get automatic performance
/// monitoring.
@experimental
// ignore: non_constant_identifier_names
SentryHiveInterface SentryHive = SentryHiveImpl(Hive);
