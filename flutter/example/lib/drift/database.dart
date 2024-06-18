// import 'package:drift/drift.dart';
//
// part 'database.g.dart';
//
// class TodoItems extends Table {
//   IntColumn get id => integer().autoIncrement()();
//   TextColumn get title => text().withLength(min: 6, max: 32)();
//   TextColumn get content => text().named('body')();
//   IntColumn get category => integer().nullable()();
// }
//
// @DriftDatabase(tables: [TodoItems])
// class AppDatabase extends _$AppDatabase {
//   AppDatabase(super.e);
//
//   @override
//   int get schemaVersion => 1;
// }
