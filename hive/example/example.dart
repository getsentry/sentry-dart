import 'package:sentry/sentry.dart';
import 'package:hive/hive.dart';
import 'package:sentry_hive/sentry_hive.dart';

part 'main.g.dart';

Future<void> main() async {
  // ATTENTION: Change the DSN below with your own to see the events in Sentry. Get one at sentry.io
  const dsn =
      'https://e85b375ffb9f43cf8bdf9787768149e0@o447951.ingest.sentry.io/5428562';

  await Sentry.init(
    (options) {
      options.dsn = dsn;
      options.tracesSampleRate = 1.0;
      options.debug = true;
    },
    appRunner: runApp, // Init your App.
  );
}

Future<void> runApp() async {
  // Use [SentryHive] where you would use [Hive]
  SentryHive
    ..init(Directory.current.path)
    ..registerAdapter(PersonAdapter());

  var box = await SentryHive.openBox('testBox');

  var person = Person(
    name: 'Dave',
    age: 22,
  );

  await box.put('dave', person);

  print(box.get('dave')); // Dave: 22
}

@HiveType(typeId: 1)
class Person {
  Person({required this.name, required this.age});

  @HiveField(0)
  String name;

  @HiveField(1)
  int age;

  @override
  String toString() {
    return '$name: $age';
  }
}
