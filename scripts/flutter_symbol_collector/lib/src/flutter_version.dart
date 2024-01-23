import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

@immutable
class FlutterVersion {
  final String tagName;

  late final engineVersion = http
      .get(Uri.https('raw.githubusercontent.com',
          'flutter/flutter/$tagName/bin/internal/engine.version'))
      .then((value) => value.body.trim());

  FlutterVersion(this.tagName);

  bool get isPreRelease => tagName.endsWith('.pre');
}
