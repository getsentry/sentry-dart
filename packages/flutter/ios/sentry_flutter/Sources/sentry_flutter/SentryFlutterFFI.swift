import Sentry

#if SWIFT_PACKAGE
import Sentry._Hybrid
import sentry_flutter_objc
#endif

/*
 Why this file exists
 - Provides a small, hand-written FFI/bridging surface for Cocoa when we need behavior that generated bindings can't express.
 - Use this only for custom needs such as serializing to JSON and guaranteeing UTF-8 encoding, or accessing Cocoa internals not exposed by generated APIs.
 - For everything else, prefer calling the generated FFI/APIs directly from Dart.
 - Keep `SentryFlutterFFI.h` in sync with the Swift `@objc` selectors (names/signatures).
 */

@objcMembers
@objc(SentryFlutterFFI)
public class SentryFlutterFFI: NSObject {
    @objc(loadDebugImagesAsBytes:) public class func loadDebugImagesAsBytes(instructionAddresses: Set<String>) -> NSData {
        var debugImages: [DebugMeta] = []

        var imagesAddresses: Set<String> = []

        for address in instructionAddresses {
            let hexDigits = address.replacingOccurrences(of: "0x", with: "")
            if let instructionAddress = UInt64(hexDigits, radix: 16) {
                let image = SentryDependencyContainer.sharedInstance().binaryImageCache.image(
                    byAddress: instructionAddress)
                if let image = image {
                    let imageAddress = sentry_formatHexAddressUInt64(image.address)!
                    imagesAddresses.insert(imageAddress)
                }
            }
        }
        debugImages =
          SentryDependencyContainer.sharedInstance().debugImageProvider
          .getDebugImagesForImageAddressesFromCache(imageAddresses: imagesAddresses) as [DebugMeta]

        if debugImages.isEmpty {
            debugImages = PrivateSentrySDKOnly.getDebugImages() as [DebugMeta]
        }

        let serializedImages = debugImages.map { $0.serialize() }
        if let data = try? JSONSerialization.data(withJSONObject: serializedImages, options: []) {
            return data as NSData
        }
        return NSData()
    }

    @objc public class func loadContextsAsBytes() -> NSData {
            var infos: [String: Any] = [:]

            SentrySDK.configureScope { scope in
                let serializedScope = scope.serialize()

                var context: [String: Any] = [:]
                if let newContext = serializedScope["context"] as? [String: Any] {
                    context = newContext
                }

                if let tags = serializedScope["tags"] as? [String: String] {
                    infos["tags"] = tags
                }
                if let extra = serializedScope["extra"] as? [String: Any] {
                    infos["extra"] = extra
                }
                if let user = serializedScope["user"] as? [String: Any] {
                    infos["user"] = user
                }
                if let dist = serializedScope["dist"] as? String {
                    infos["dist"] = dist
                }
                if let environment = serializedScope["environment"] as? String {
                    infos["environment"] = environment
                }
                if let fingerprint = serializedScope["fingerprint"] as? [String] {
                    infos["fingerprint"] = fingerprint
                }
                if let level = serializedScope["level"] as? String {
                    infos["level"] = level
                }
                if let breadcrumbs = serializedScope["breadcrumbs"] as? [[String: Any]] {
                    infos["breadcrumbs"] = breadcrumbs
                }

                if let user = serializedScope["user"] as? [String: Any] {
                    infos["user"] = user
                } else {
                    infos["user"] = ["id": PrivateSentrySDKOnly.installationID]
                }

                if let integrations = PrivateSentrySDKOnly.options.integrations {
                    infos["integrations"] = integrations.filter { $0 != "SentrySessionReplayIntegration" }
                }

                let deviceStr = "device"
                let appStr = "app"
                if let extraContext = PrivateSentrySDKOnly.getExtraContext() as? [String: Any] {
                    // merge device
                    if let extraDevice = extraContext[deviceStr] as? [String: Any] {
                        if var currentDevice = context[deviceStr] as? [String: Any] {
                            currentDevice.merge(extraDevice) { (current, _) in current }
                            context[deviceStr] = currentDevice
                        } else {
                            context[deviceStr] = extraDevice
                        }
                    }

                    // merge app
                    if let extraApp = extraContext[appStr] as? [String: Any] {
                        if var currentApp = context[appStr] as? [String: Any] {
                            currentApp.merge(extraApp) { (current, _) in current }
                            context[appStr] = currentApp
                        } else {
                            context[appStr] = extraApp
                        }
                    }
                }

                infos["contexts"] = context

                // Not reading the name from PrivateSentrySDKOnly.getSdkName because
                // this is added as a package and packages should follow the sentry-release-registry format
                infos["package"] = ["version": PrivateSentrySDKOnly.getSdkVersionString(),
                    "sdk_name": "cocoapods:sentry-cocoa"]

            }
            if let data = try? JSONSerialization.data(withJSONObject: infos, options: []) {
                return data as NSData
            }
            return NSData()
    }
}


