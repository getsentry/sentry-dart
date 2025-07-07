# Sentry Flutter macOS Framework Build Workaround

## Issue

When building Flutter as a macOS framework using `flutter build macos-framework`, you may encounter build errors related to missing Sentry headers:
- `SentrySdkInfo.h` not found
- `SentryInternalSerializable.h` not found

This happens because the Sentry Cocoa SDK's private headers aren't properly included when building as a framework (as opposed to a full app).

## Workarounds

### Option 1: Use the Helper Script in Your Podfile

If you're integrating the Flutter framework into a macOS app using CocoaPods, add this to your app's Podfile:

```ruby
require_relative '../path/to/flutter/macos/sentry_flutter_framework_helper'

post_install do |installer|
  configure_sentry_for_framework_build(installer)
end
```

### Option 2: Manual Header Configuration

Add these build settings to your Xcode project that consumes the Flutter framework:

1. In your app target's Build Settings, add to "Header Search Paths":
   - `$(PODS_CONFIGURATION_BUILD_DIR)/Sentry/Sentry.framework/Headers`
   - `$(PODS_CONFIGURATION_BUILD_DIR)/Sentry/Sentry.framework/PrivateHeaders`

2. Add to "Other C Flags":
   - `-fmodule-map-file="${PODS_CONFIGURATION_BUILD_DIR}/Sentry/Sentry.framework/Modules/module.modulemap"`

### Option 3: Use Pre-compiled Sentry Framework

Replace the Sentry.xcframework with a pre-compiled version that includes all necessary headers:

1. Download the Sentry.xcframework from: https://github.com/getsentry/sentry-cocoa/releases
2. Replace the framework in your build output
3. Ensure both Headers and PrivateHeaders directories are included

### Option 4: Add Missing Headers Manually

As a temporary workaround, you can manually add the missing headers:

1. Download the missing headers from the Sentry Cocoa SDK repository
2. Add them to the Sentry.framework/PrivateHeaders directory in your build output
3. Required headers:
   - `SentrySdkInfo.h`
   - `SentryInternalSerializable.h`

## Long-term Solution

We're working on a permanent fix to ensure the Flutter framework build process properly includes all necessary Sentry headers. Track the issue at: https://github.com/getsentry/sentry-dart/issues/[ISSUE_NUMBER]

## Additional Notes

- This issue only affects framework builds (`flutter build macos-framework`)
- Direct Flutter app builds (`flutter run` or `flutter build macos`) work correctly
- The issue is related to how CocoaPods handles transitive dependencies in framework builds