import 'package:hive/hive.dart';
import 'package:hive/src/box_collection/box_collection_stub.dart'
    if (dart.library.js_interop) 'package:hive/src/box_collection/box_collection_indexed_db.dart'
    if (dart.library.io) 'package:hive/src/box_collection/box_collection.dart'
    as impl;
import 'package:mockito/annotations.dart';
import 'package:sentry/sentry.dart';

@GenerateMocks([
  Hub,
  Box,
  LazyBox,
  HiveInterface,
  // Edit generated code to make sure correct impl/stub class is used
  impl.BoxCollection,
])
void main() {}
