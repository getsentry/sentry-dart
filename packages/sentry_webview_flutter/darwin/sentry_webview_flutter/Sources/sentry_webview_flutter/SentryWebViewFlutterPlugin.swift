#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif

public final class SentryWebViewFlutterPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {}
}
