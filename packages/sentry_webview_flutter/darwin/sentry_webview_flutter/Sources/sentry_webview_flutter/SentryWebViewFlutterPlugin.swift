#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif
import WebKit
import webview_flutter_wkwebview

public final class SentryWebViewFlutterPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        #if os(iOS)
        let messenger = registrar.messenger()
        #else
        let messenger = registrar.messenger
        #endif
        let channel = FlutterMethodChannel(name: "sentry_flutter/webview_tracing", binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            guard call.method == "setTraceScript" else {
                result(FlutterMethodNotImplemented)
                return
            }
            guard let arguments = call.arguments as? [String: Any],
                  let identifier = arguments["identifier"] as? NSNumber else {
                result(false)
                return
            }
            #if os(iOS)
            let view = FWFWebViewFlutterWKWebViewExternalAPI.webView(
                forIdentifier: identifier.int64Value, withPluginRegistrar: registrar)
            #else
            guard let registry = registrar.viewController as? FlutterPluginRegistry else {
                result(false)
                return
            }
            let view = FWFWebViewFlutterWKWebViewExternalAPI.webView(
                forIdentifier: identifier.int64Value, withPluginRegistry: registry)
            #endif
            guard let view else {
                result(false)
                return
            }
            let source = arguments["source"] as? String
            let controller = view.configuration.userContentController
            let scripts = controller.userScripts
            let preserved = scripts.filter { !$0.source.hasPrefix("/* sentry-flutter-webview-trace */") }
            if source != nil || preserved.count != scripts.count {
                controller.removeAllUserScripts()
                if let source {
                    let script = WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
                    controller.addUserScript(script)
                }
                for script in preserved {
                    controller.addUserScript(script)
                }
            }
            result(source != nil)
        }
    }
}
