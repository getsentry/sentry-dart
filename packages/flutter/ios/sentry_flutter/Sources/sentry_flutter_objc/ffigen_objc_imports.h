#include <stdint.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "SentryFlutterPlugin.h"
#import "SentryFlutterReplayScreenshotProvider.h"

// Forward protocol declarations to avoid hard dependency on Sentry SDK at build time.
@protocol SentrySpan;
@protocol SentrySerializable;
@protocol SentryRedactOptions;

#ifdef FFIGEN
// Only included while running ffigen (provide -I paths in compiler-opts).
#import "PrivateSentrySDKOnly.h"
#import "Sentry-Swift.h"
#import "SentryOptions.h"
#import "SentryScope.h"
#endif
