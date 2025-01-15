import 'package:sentry_flutter/src/web/script_loader/script_dom_api.dart';

export 'html_utils.dart' if (dart.library.js_interop) 'web_utils.dart';

List<SentryScriptElement> fetchAllScripts() {
  return fetchScripts('script');
}
