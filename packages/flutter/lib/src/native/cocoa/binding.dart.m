#include <stdint.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "../../../../temp/Sentry.framework/PrivateHeaders/PrivateSentrySDKOnly.h"
#import "../../../../temp/Sentry.framework/Headers/Sentry-Swift.h"
#import "../../../../temp/Sentry.framework/Headers/SentryScope.h"
#import "../../../../temp/Sentry.framework/Headers/SentryDebugMeta.h"
#import "../../../../temp/Sentry.framework/PrivateHeaders/SentryDependencyContainer.h"
#import "../../../../temp/Sentry.framework/PrivateHeaders/SentryDebugImageProvider+HybridSDKs.h"
#import "../../../../temp/Sentry.framework/PrivateHeaders/SentryBinaryImageCache.h"

#if !__has_feature(objc_arc)
#error "This file must be compiled with ARC enabled"
#endif

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

typedef struct {
  int64_t version;
  void* (*newWaiter)(void);
  void (*awaitWaiter)(void*);
  void* (*currentIsolate)(void);
  void (*enterIsolate)(void*);
  void (*exitIsolate)(void);
  int64_t (*getMainPortId)(void);
  bool (*getCurrentThreadOwnsIsolate)(int64_t);
} DOBJC_Context;

id objc_retainBlock(id);

#define BLOCKING_BLOCK_IMPL(ctx, BLOCK_SIG, INVOKE_DIRECT, INVOKE_LISTENER)    \
  assert(ctx->version >= 1);                                                   \
  void* targetIsolate = ctx->currentIsolate();                                 \
  int64_t targetPort = ctx->getMainPortId == NULL ? 0 : ctx->getMainPortId();  \
  return BLOCK_SIG {                                                           \
    void* currentIsolate = ctx->currentIsolate();                              \
    bool mayEnterIsolate =                                                     \
        currentIsolate == NULL &&                                              \
        ctx->getCurrentThreadOwnsIsolate != NULL &&                            \
        ctx->getCurrentThreadOwnsIsolate(targetPort);                          \
    if (currentIsolate == targetIsolate || mayEnterIsolate) {                  \
      if (mayEnterIsolate) {                                                   \
        ctx->enterIsolate(targetIsolate);                                      \
      }                                                                        \
      INVOKE_DIRECT;                                                           \
      if (mayEnterIsolate) {                                                   \
        ctx->exitIsolate();                                                    \
      }                                                                        \
    } else {                                                                   \
      void* waiter = ctx->newWaiter();                                         \
      INVOKE_LISTENER;                                                         \
      ctx->awaitWaiter(waiter);                                                \
    }                                                                          \
  };


Protocol* _SentryCocoa_SentrySpan(void) { return @protocol(SentrySpan); }

typedef void  (^ListenerTrampoline)(id arg0);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline _SentryCocoa_wrapListenerBlock_xtuoz7(ListenerTrampoline block) NS_RETURNS_RETAINED {
  return ^void(id arg0) {
    objc_retainBlock(block);
    block((__bridge id)(__bridge_retained void*)(arg0));
  };
}

typedef void  (^BlockingTrampoline)(void * waiter, id arg0);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline _SentryCocoa_wrapBlockingBlock_xtuoz7(
    BlockingTrampoline block, BlockingTrampoline listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(id arg0), {
    objc_retainBlock(block);
    block(nil, (__bridge id)(__bridge_retained void*)(arg0));
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, (__bridge id)(__bridge_retained void*)(arg0));
  });
}

typedef id  (^ProtocolTrampoline)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
id  _SentryCocoa_protocolTrampoline_1mbt9g9(id target, void * sel) {
  return ((ProtocolTrampoline)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

Protocol* _SentryCocoa_SentrySpan(void) { return @protocol(SentrySpan); }

typedef void  (^ListenerTrampoline_1)(int * arg0);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_1 _SentryCocoa_wrapListenerBlock_15zdkpa(ListenerTrampoline_1 block) NS_RETURNS_RETAINED {
  return ^void(int * arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^BlockingTrampoline_1)(void * waiter, int * arg0);
__attribute__((visibility("default"))) __attribute__((used))
ListenerTrampoline_1 _SentryCocoa_wrapBlockingBlock_15zdkpa(
    BlockingTrampoline_1 block, BlockingTrampoline_1 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(int * arg0), {
    objc_retainBlock(block);
    block(nil, arg0);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0);
  });
}

Protocol* _SentryCocoa_SentrySerializable(void) { return @protocol(SentrySerializable); }

Protocol* _SentryCocoa_SentryRandom(void) { return @protocol(SentryRandom); }

Protocol* _SentryCocoa_SentryCurrentDateProvider(void) { return @protocol(SentryCurrentDateProvider); }

Protocol* _SentryCocoa_SentryNSNotificationCenterWrapper(void) { return @protocol(SentryNSNotificationCenterWrapper); }

Protocol* _SentryCocoa_SentryRateLimits(void) { return @protocol(SentryRateLimits); }

Protocol* _SentryCocoa_SentryApplication(void) { return @protocol(SentryApplication); }

Protocol* _SentryCocoa_SentryANRTracker(void) { return @protocol(SentryANRTracker); }

Protocol* _SentryCocoa_SentryDispatchQueueProviderProtocol(void) { return @protocol(SentryDispatchQueueProviderProtocol); }

Protocol* _SentryCocoa_SentryObjCRuntimeWrapper(void) { return @protocol(SentryObjCRuntimeWrapper); }
#undef BLOCKING_BLOCK_IMPL

#pragma clang diagnostic pop
