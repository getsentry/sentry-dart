//
// Generated file. Do not edit.
//

// ignore_for_file: directives_ordering
// ignore_for_file: lines_longer_than_80_chars
// ignore_for_file: depend_on_referenced_packages

// import 'package:package_info_plus_web/package_info_plus_web.dart';
import 'package:sentry_flutter/sentry_flutter_web.dart';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

// ignore: public_member_api_docs
void registerPlugins(Registrar registrar) {
  // PackageInfoPlugin.registerWith(registrar);
  SentryFlutterWeb.registerWith(registrar);
  registrar.registerMessageHandler();
}
