package io.sentry.flutter.webview;

import android.webkit.WebView;
import androidx.annotation.NonNull;
import androidx.webkit.ScriptHandler;
import androidx.webkit.WebViewCompat;
import androidx.webkit.WebViewFeature;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.WeakHashMap;

public final class SentryWebViewFlutterPlugin implements FlutterPlugin {
  // The WebView owns its handle, which may itself retain the WebView.
  private final Set<WebView> registered = Collections.newSetFromMap(new WeakHashMap<>());
  private MethodChannel channel;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    channel = new MethodChannel(binding.getBinaryMessenger(), "sentry_flutter/webview_tracing");
    // webview_flutter creates its WebViews on the platform thread. The default
    // channel handler and engine lifecycle callbacks run on that same thread.
    channel.setMethodCallHandler(
        (call, result) -> {
          if (!call.method.equals("setTraceScript")) {
            result.notImplemented();
            return;
          }
          try {
            Number identifier = call.argument("identifier");
            WebView view = WebViewFlutterAndroidExternalApi.getWebView(binding, identifier.longValue());
            if (view == null
                || !WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
              result.success(false);
              return;
            }
            removeScript(view);
            registered.remove(view);
            String source = call.argument("source");
            if (source != null) {
              List<String> origins = call.argument("origins");
              ScriptHandler handle =
                  WebViewCompat.addDocumentStartJavaScript(view, source, new HashSet<>(origins));
              view.setTag(R.id.sentry_webview_trace_script, handle);
              registered.add(view);
            }
            result.success(source != null);
          } catch (RuntimeException ignored) {
            result.success(false);
          }
        });
  }

  private static void removeScript(WebView view) {
    ScriptHandler handle = (ScriptHandler) view.getTag(R.id.sentry_webview_trace_script);
    if (handle != null) {
      handle.remove();
      view.setTag(R.id.sentry_webview_trace_script, null);
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
    channel = null;
    for (WebView view : registered) {
      try {
        removeScript(view);
      } catch (RuntimeException ignored) {
        // The host may already have destroyed this WebView.
      }
    }
    registered.clear();
  }
}
