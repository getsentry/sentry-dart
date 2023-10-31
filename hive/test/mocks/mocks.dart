import 'package:hive/hive.dart';
import 'package:mockito/annotations.dart';
import 'package:sentry/sentry.dart';

import 'package:hive/src/box_collection/box_collection_stub.dart'
    if (dart.library.html) 'package:hive/src/box_collection/box_collection_indexed_db.dart'
    if (dart.library.io) 'package:hive/src/box_collection/box_collection.dart'
    as impl;

@GenerateMocks([
  Hub,
  Box,
  LazyBox,
  HiveInterface,
  // Edit generated code to make sure correct impl/stub class is used
  impl.BoxCollection,
])
void main() {}
