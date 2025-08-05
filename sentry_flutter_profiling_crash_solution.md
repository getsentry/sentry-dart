# Sentry Flutter SDK iOS Profiling Crash Solution

## Problem Description

When using Sentry Flutter SDK with profiling enabled on iOS, the app crashes with an `NSInternalInconsistencyException`. The error message indicates:

```
Expected a profiler to be associated with tracer id 13dcd2a23cee47a281c96060ee9a8e0e
```

This crash occurs when:
1. Profile events are being dropped due to rate limiting
2. The profiler expects to find a profiler instance associated with a specific tracer ID but doesn't find one

## Root Cause Analysis

The crash is related to a race condition in the Sentry iOS SDK's profiling implementation where:

1. Profile data is being rate-limited and dropped (as shown by the warning messages)
2. The SDK still expects a profiler instance to exist for active traces
3. When the profiler can't be found for a tracer ID, it throws an `NSInternalInconsistencyException`

## Solutions to Prevent App Crashes

### Solution 1: Disable Profiling (Immediate Fix)

The quickest way to prevent crashes is to disable profiling entirely:

```dart
import 'package:sentry_flutter/sentry_flutter.dart';

await SentryFlutter.init(
  (options) {
    options.dsn = 'YOUR_DSN_HERE';
    
    // Keep tracing enabled if needed
    options.tracesSampleRate = 1.0;
    
    // DISABLE profiling to prevent crashes
    // options.profilesSampleRate = 0.0; // Don't set this
    // Remove any profiling configuration
  },
);
```

### Solution 2: Reduce Profiling Sample Rate

If you need profiling but want to reduce the likelihood of rate limiting:

```dart
await SentryFlutter.init(
  (options) {
    options.dsn = 'YOUR_DSN_HERE';
    
    // Reduce sampling rates to avoid rate limiting
    options.tracesSampleRate = 0.1; // 10% of transactions
    options.profilesSampleRate = 0.01; // 1% of traced transactions
  },
);
```

### Solution 3: Implement Conditional Profiling

Enable profiling only for specific builds or environments:

```dart
await SentryFlutter.init(
  (options) {
    options.dsn = 'YOUR_DSN_HERE';
    options.tracesSampleRate = 1.0;
    
    // Only enable profiling in debug/development builds
    if (kDebugMode) {
      options.profilesSampleRate = 0.1;
    }
    // In release builds, profiling is disabled by not setting profilesSampleRate
  },
);
```

### Solution 4: Use Dynamic Sampling

Implement a custom sampler to control when profiling is enabled:

```dart
await SentryFlutter.init(
  (options) {
    options.dsn = 'YOUR_DSN_HERE';
    options.tracesSampleRate = 1.0;
    
    // Use tracesSampler for more control
    options.tracesSampler = (samplingContext) {
      // Disable profiling for specific transactions
      if (samplingContext.transactionContext?.name?.contains('problematic') ?? false) {
        return 0.0; // No sampling for problematic transactions
      }
      return 0.1; // 10% for others
    };
    
    // Keep a low profile sample rate
    options.profilesSampleRate = 0.01;
  },
);
```

### Solution 5: Platform-Specific Configuration

Disable profiling only on iOS while keeping it enabled on other platforms:

```dart
import 'dart:io';
import 'package:sentry_flutter/sentry_flutter.dart';

await SentryFlutter.init(
  (options) {
    options.dsn = 'YOUR_DSN_HERE';
    options.tracesSampleRate = 1.0;
    
    // Only enable profiling on non-iOS platforms
    if (!Platform.isIOS) {
      options.profilesSampleRate = 0.1;
    }
  },
);
```

### Solution 6: Error Handling Wrapper

Wrap your Sentry initialization with error handling:

```dart
Future<void> initializeSentry() async {
  try {
    await SentryFlutter.init(
      (options) {
        options.dsn = 'YOUR_DSN_HERE';
        options.tracesSampleRate = 1.0;
        
        // Add beforeSend to catch profiling-related errors
        options.beforeSend = (event, hint) {
          // Filter out profiling-related crashes
          if (event.throwable?.toString().contains('SentryProfiledTracerConcurrency') ?? false) {
            return null; // Don't send this event
          }
          return event;
        };
        
        // Use conservative profiling settings
        options.profilesSampleRate = 0.01;
      },
    );
  } catch (error) {
    print('Sentry initialization error: $error');
    // Continue app execution even if Sentry fails
  }
}
```

## Recommended Production Configuration

For production apps, use this configuration to minimize crashes:

```dart
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

await SentryFlutter.init(
  (options) {
    options.dsn = 'YOUR_DSN_HERE';
    
    // Basic error tracking
    options.debug = kDebugMode;
    
    // Performance monitoring with conservative settings
    options.tracesSampleRate = 0.1; // 10% of transactions
    
    // Disable profiling on iOS in production
    if (!Platform.isIOS && !kReleaseMode) {
      options.profilesSampleRate = 0.01; // 1% of traces
    }
    
    // Set reasonable timeouts
    options.autoSessionTrackingInterval = const Duration(seconds: 30);
    
    // Add error filtering
    options.beforeSend = (event, hint) {
      // Filter out known profiling issues
      final error = event.throwable?.toString() ?? '';
      if (error.contains('SentryProfiledTracerConcurrency') ||
          error.contains('Expected a profiler to be associated')) {
        return null;
      }
      return event;
    };
  },
);
```

## Additional Recommendations

1. **Update SDK Versions**: Ensure you're using the latest versions of both Sentry Flutter SDK and the native iOS SDK.

2. **Monitor Rate Limits**: Check your Sentry dashboard for rate limiting issues and adjust your quota or sampling rates accordingly.

3. **Test Thoroughly**: Test profiling configuration in a staging environment before deploying to production.

4. **Gradual Rollout**: If you need profiling, enable it gradually:
   - Start with 0.1% sampling rate
   - Monitor for crashes
   - Gradually increase if stable

5. **Consider Alternatives**: For iOS performance monitoring, consider using:
   - Native iOS performance tools (Instruments)
   - Firebase Performance Monitoring
   - Custom performance metrics without profiling

## Monitoring the Fix

After implementing the solution:

1. Monitor crash reports for any `NSInternalInconsistencyException` occurrences
2. Check Sentry dashboard for successful transaction captures
3. Verify that basic error tracking still works
4. If using reduced profiling, monitor that some profiles are still being captured

## Long-term Solution

The ideal long-term solution would be for Sentry to fix the underlying issue in their iOS SDK. You can:

1. Report this issue to Sentry's GitHub repository
2. Subscribe to updates on similar issues
3. Wait for an SDK update that addresses this race condition

Until then, the safest approach for production apps is to disable profiling on iOS or use very conservative sampling rates.