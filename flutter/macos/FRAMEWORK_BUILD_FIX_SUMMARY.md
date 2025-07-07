# Fix for macOS Framework Build Missing Headers Issue

## Problem Summary

When building Flutter as a macOS framework using `flutter build macos-framework`, the build fails with missing header errors:
- `'SentrySdkInfo.h' file not found`
- `'SentryInternalSerializable.h' file not found`

This occurs because the Sentry Cocoa SDK's private headers aren't properly exposed when building as a framework, unlike when building a complete macOS app.

## Root Cause

1. The sentry_flutter plugin depends on private headers from the Sentry Cocoa SDK
2. CocoaPods handles dependencies differently for framework builds vs app builds
3. The `Sentry/HybridSDK` subspec doesn't properly expose private headers in framework contexts

## Changes Made

### 1. Updated macOS podspec (`sentry_flutter.podspec`)
- Added header search paths for Sentry private headers
- Added preserve_paths to maintain framework structure
- Added a script phase to verify private headers availability
- Enhanced pod_target_xcconfig with proper header and module configurations

### 2. Created Framework Helper Script (`sentry_flutter_framework_helper.rb`)
- Ruby helper script for Podfile integration
- Configures header search paths dynamically
- Can be used in consuming apps' Podfiles

### 3. Added Fallback Imports in Objective-C Files
- Modified `SentryFlutterReplayBreadcrumbConverter.m`
- Modified `SentryFlutterReplayScreenshotProvider.m`
- Added conditional imports using `__has_include` to handle different build scenarios

### 4. Created Documentation
- `FRAMEWORK_BUILD_WORKAROUND.md` - User-facing documentation with multiple workaround options
- `FRAMEWORK_BUILD_FIX_SUMMARY.md` - This summary for maintainers

## How These Changes Help

1. **Podspec changes**: Ensure proper header paths are set during pod installation
2. **Helper script**: Provides a reusable solution for app developers
3. **Fallback imports**: Make the code more resilient to different build configurations
4. **Documentation**: Helps users understand and work around the issue until a permanent fix is available

## Testing

To test these changes:
1. Create a Flutter project with sentry_flutter dependency
2. Run `flutter build macos-framework`
3. Create a new macOS app and integrate the framework
4. Verify the build succeeds without header errors

## Future Improvements

- Consider working with the Sentry Cocoa team to improve private header exposure in the HybridSDK subspec
- Investigate if FFI bindings can be generated without requiring private headers
- Explore using Swift Package Manager as an alternative to CocoaPods for better framework support