export 'sentry_script_loader_factory_unsupported.dart'
    if (dart.library.html) 'sentry_script_loader_factory_web.dart'
    if (dart.library.js_interop) 'sentry_script_loader_factory_web.dart';
