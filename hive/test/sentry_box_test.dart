@TestOn('vm')

import 'dart:io';

import 'package:hive/hive.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:test/test.dart';
import 'package:sentry/src/sentry_tracer.dart';

import 'mocks/mocks.mocks.dart';

void main() {

  void verifySpan(SentrySpan? span) {
    expect(span?.status, SpanStatus.ok());
    expect(span?.data[SentryHive.dbSystemKey], SentryHive.dbSystem);
    expect(span?.data[SentryHive.dbNameKey], Fixture.dbName);
  }

  group('span tests', () {

    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
      await fixture.setUp();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    test('add adds span', () async {
      final sut = await fixture.getSut();

      await sut.add(Person('Joe Dirt'));

      verifySpan(fixture.getCreatedSpan());
    });
  });
}

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
    return Person(reader.readString());
  }

  @override
  void write(BinaryWriter writer, Person obj) {
    writer.write(obj.name);
  }
}

class Fixture {
  late final Box<Person> box;
  final options = SentryOptions();
  final hub = MockHub();
  static final dbName = 'people';

  final _context = SentryTransactionContext('name', 'operation');
  late final tracer = SentryTracer(_context, hub);

  Future<void> setUp() async {
    Hive.init(Directory.systemTemp.path);
    Hive.registerAdapter(PersonAdapter());

    box = await Hive.openBox(dbName);
  }

  Future<void> tearDown() async {
    if (box.isOpen) {
      await box.deleteFromDisk();
      await box.close();
    }
  }

  Future<SentryBox<Person>> getSut() async {
    return SentryBox(box, hub);
  }

  SentrySpan? getCreatedSpan() {
    return tracer.children.last;
  }
}
