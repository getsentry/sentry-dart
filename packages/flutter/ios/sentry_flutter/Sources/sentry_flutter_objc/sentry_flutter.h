// Minimal umbrella header to make the module importable from the generated
// sentry_flutter-Swift.h and expose public ObjC types used by Swift.
// Keep this header lightweight and only import the public surface needed by ObjC.
//
// Example:
// - Swift exposes an ObjC-facing API:
//     @objc(setupReplay:tags:)
//     public class func setupReplay(callback: @escaping SentryReplayCaptureCallback, tags: [String: Any])
// - Because the signature references the ObjC typedef SentryReplayCaptureCallback,
//   Xcode generates sentry_flutter-Swift.h that imports:
//     #import <sentry_flutter/sentry_flutter.h>
// - If this umbrella header is missing, the build fails with:
//     'sentry_flutter/sentry_flutter.h' file not found.
//
#import <Foundation/Foundation.h>
// Public typedef for the replay callback and provider interface.
#import "SentryFlutterReplayScreenshotProvider.h"
