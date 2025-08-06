import 'package:drift/backends.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

QueryExecutor inMemoryExecutor() {
  return NativeDatabase.memory();
}
