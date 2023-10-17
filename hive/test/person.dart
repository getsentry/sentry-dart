import 'package:hive/hive.dart';

@HiveType(typeId: 0)
class Person extends HiveObject {
  @HiveField(0)
  final String name;

  Person(this.name);
}

class PersonAdapter extends TypeAdapter<Person> {
  @override
  final typeId = 0;

  @override
  Person read(BinaryReader reader) {
    return Person(reader.read() as String);
  }

  @override
  void write(BinaryWriter writer, Person obj) {
    writer.write(obj.name);
  }
}