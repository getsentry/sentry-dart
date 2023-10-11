import 'package:http/http.dart' as http;

class FlutterVersion {
  final String tagName;

  FlutterVersion(this.tagName);

  bool get isPreRelease => tagName.endsWith('.pre');

  Future<String> getEngineVersion() => http
      .get(Uri.https('raw.githubusercontent.com',
          'flutter/flutter/$tagName/bin/internal/engine.version'))
      .then((value) => value.body.trim());
}
