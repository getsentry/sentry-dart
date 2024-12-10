#pragma once

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FLUTTER_PLUGIN_EXPORT
#endif

typedef struct _SentryFlutterPlugin SentryFlutterPlugin;
typedef struct {
  GObjectClass parent_class;
} SentryFlutterPluginClass;

FLUTTER_PLUGIN_EXPORT void sentry_flutter_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {}

G_END_DECLS
