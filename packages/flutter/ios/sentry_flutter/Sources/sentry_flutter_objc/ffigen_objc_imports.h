// ios/sentry_flutter/Sources/sentry_flutter_objc/ffigen_objc_imports.h
#include <stdint.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "SentryFlutterPlugin.h"

// Forward protocol declarations to avoid hard dependency on Sentry SDK at build time.
@protocol SentrySpan;
@protocol SentrySerializable;

#ifdef FFIGEN
// Only included while running ffigen (provide -I paths in compiler-opts).
#import "PrivateSentrySDKOnly.h"
#import "Sentry-Swift.h"
#import "SentryOptions.h"
#import "SentryScope.h"
#endif
