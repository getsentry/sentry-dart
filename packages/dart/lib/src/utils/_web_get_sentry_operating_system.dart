import '../protocol/sentry_operating_system.dart';
import 'package:meta/meta.dart';

@internal
SentryOperatingSystem getSentryOperatingSystem({
  String? name,
  String? rawDescription,
}) {
  final os = SentryOperatingSystem();
  os.name = name ?? os.name;
  os.rawDescription = rawDescription ?? os.rawDescription;
  return os;
}
