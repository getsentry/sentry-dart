import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

@immutable
class FlutterVersion {
  final String tagName;

  late final engineVersion = () async {
    final url = Uri.https('raw.githubusercontent.com',
        'flutter/flutter/$tagName/bin/internal/engine.version');
    final response = await http.get(url);
    if (response.statusCode ~/ 100 != 2) {
      throw HttpException(
          'Failed to fetch engine version. Response status code: ${response.statusCode}',
          uri: url);
    }
    return response.body.trim();
  }();

  FlutterVersion(this.tagName);

  bool get isPreRelease => tagName.endsWith('.pre');
}
