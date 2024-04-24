import Foundation
import Sentry

@objc
class SentryFlutterReplayIntegration: NSObject, SentryIntegrationProtocol {
    // private var sessionReplay: SentrySessionReplay = null

    func install(with options: Options) -> Bool {
        // if #available(iOS 16.0, tvOS 16.0, *) {
        //     guard let replayOptions = options.experimental.sessionReplay else {
        //         return false
        //     }

        //     let shouldReplayFullSession = SentryDependencyContainer.sharedInstance.random.nextNumber() < replayOptions.sessionSampleRate
        //     if !shouldReplayFullSession && replayOptions.errorSampleRate == 0 {
        //         return false
        //     }

        //     let replayDir = URL(fileURLWithPath: SentryDependencyContainer.sharedInstance.fileManager.sentryPath)
        //         .appendingPathComponent(SENTRY_REPLAY_FOLDER)
        //         .appendingPathComponent(UUID().uuidString)

        //     if !FileManager.default.fileExists(atPath: replayDir.path) {
        //         try? FileManager.default.createDirectory(at: replayDir, withIntermediateDirectories: true, attributes: nil)
        //     }

        //     let replayMaker = SentryOnDemandReplay(outputPath: replayDir.path)
        //     replayMaker.bitRate = replayOptions.replayBitRate
        //     replayMaker.cacheMaxSize = shouldReplayFullSession ? replayOptions.sessionSegmentDuration : replayOptions.errorReplayDuration

        //     self.sessionReplay = SentrySessionReplay(
        //         settings: replayOptions,
        //         replayFolderPath: replayDir,
        //         screenshotProvider: SentryViewPhotographer.shared,
        //         replayMaker: replayMaker,
        //         dateProvider: SentryDependencyContainer.sharedInstance.dateProvider,
        //         random: SentryDependencyContainer.sharedInstance.random,
        //         displayLinkWrapper: SentryDisplayLinkWrapper()
        //     )

        //     self.sessionReplay.start(
        //         SentryDependencyContainer.sharedInstance.application.windows.first,
        //         fullSession: shouldReplayFullSession
        //     )

        //     NotificationCenter.default.addObserver(
        //         self,
        //         selector: #selector(stop),
        //         name: UIApplication.didEnterBackgroundNotification,
        //         object: nil
        //     )

        //     SentryGlobalEventProcessor.shared.addEventProcessor { event in
        //         self.sessionReplay.captureReplay(for: event)
        //         return event
        //     }

        //     return true
        // } else {
            return false
        // }
    }

    func uninstall() {
        // self.sessionReplay.stop()
    }
}
