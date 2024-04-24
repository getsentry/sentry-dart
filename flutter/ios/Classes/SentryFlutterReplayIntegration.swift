import Foundation
import Sentry

@objc
class SentryFlutterReplayIntegration: NSObject, SentryIntegrationProtocol {
    func install(with options: Options) -> Bool {
        print("Installing flutter replay integration")
        return true
    }

    func uninstall() {

    }
}
