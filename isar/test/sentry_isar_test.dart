import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_isar/sentry_isar.dart';
import 'package:sentry_isar/user.dart';


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('adds one to input values',  () async {
    final isar = await SentryIsar.open(
      [UserSchema],
      directory: Directory.systemTemp.path,
    );

    final newUser = User()
      ..name = 'Joe Dirt'
      ..age = 36;

    await isar.writeTxn(() async {
      await isar.users.put(newUser); // insert & update
    });

    final existingUser = await isar.users.get(newUser.id); // get

    await isar.writeTxn(() async {
      await isar.users.delete(existingUser!.id); // delete
    });
  });
}
