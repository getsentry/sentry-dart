#include "include/sentry_flutter/sentry_flutter_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>

#define SENTRY_FLUTTER_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), sentry_flutter_plugin_get_type(), \
                              SentryFlutterPlugin))

struct _SentryFlutterPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(SentryFlutterPlugin, sentry_flutter_plugin, g_object_get_type())

// Called when a method call is received from Flutter.
static void sentry_flutter_plugin_handle_method_call(
    SentryFlutterPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());

  fl_method_call_respond(method_call, response, nullptr);
}

static void sentry_flutter_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(sentry_flutter_plugin_parent_class)->dispose(object);
}

static void sentry_flutter_plugin_class_init(SentryFlutterPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = sentry_flutter_plugin_dispose;
}

static void sentry_flutter_plugin_init(SentryFlutterPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  SentryFlutterPlugin* plugin = SENTRY_FLUTTER_PLUGIN(user_data);
  sentry_flutter_plugin_handle_method_call(plugin, method_call);
}

void sentry_flutter_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  SentryFlutterPlugin* plugin = SENTRY_FLUTTER_PLUGIN(
      g_object_new(sentry_flutter_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "sentry_flutter",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
