#import "SentryFlutterReplayBreadcrumbConverter.h"

@import Sentry;

#if SENTRY_TARGET_REPLAY_SUPPORTED

@implementation SentryFlutterReplayBreadcrumbConverter {
  SentrySRDefaultBreadcrumbConverter *defaultConverter;
}

- (instancetype _Nonnull)init {
  if (self = [super init]) {
    self->defaultConverter =
        [SentrySessionReplayIntegration createDefaultBreadcrumbConverter];
  }
  return self;
}

- (id<SentryRRWebEvent> _Nullable)convertFrom:
    (SentryBreadcrumb *_Nonnull)breadcrumb {
  assert(breadcrumb.timestamp != nil);

  if ([breadcrumb.category isEqualToString:@"sentry.event"] ||
      [breadcrumb.category isEqualToString:@"sentry.transaction"]) {
    // Do not add Sentry Event breadcrumbs to replay
    return nil;
  }

  if ([breadcrumb.category isEqualToString:@"http"]) {
    // Drop native network breadcrumbs to avoid duplicates
    return nil;
  }
  if ([breadcrumb.type isEqualToString:@"navigation"] &&
      ![breadcrumb.category isEqualToString:@"navigation"]) {
    // Drop native navigation breadcrumbs to avoid duplicates
    return nil;
  }

  if ([breadcrumb.category isEqualToString:@"touch"]) {
    return [self convertTouch:breadcrumb];
  }

  if ([breadcrumb.category isEqualToString:@"navigation"]) {
    return [SentrySessionReplayIntegration
        createBreadcrumbwithTimestamp:breadcrumb.timestamp
                             category:breadcrumb.category
                              message:nil
                                level:breadcrumb.level
                                 data:breadcrumb.data];
  }

  if ([breadcrumb.category isEqualToString:@"xhr"]) {
    return [self convertNavigation:breadcrumb];
  }

  SentryRRWebEvent *nativeBreadcrumb =
      [self->defaultConverter convertFrom:breadcrumb];

  // ignore native navigation breadcrumbs
  if (nativeBreadcrumb && nativeBreadcrumb.data &&
      nativeBreadcrumb.data[@"payload"] &&
      nativeBreadcrumb.data[@"payload"][@"category"] &&
      [nativeBreadcrumb.data[@"payload"][@"category"]
          isEqualToString:@"navigation"]) {
    return nil;
  }

  return nativeBreadcrumb;
}

- (id<SentryRRWebEvent> _Nullable)convertTouch:
    (SentryBreadcrumb *_Nonnull)breadcrumb {
  if (breadcrumb.data == nil) {
    return nil;
  }

  NSString *message = @""; // TODO

  return [SentrySessionReplayIntegration
      createBreadcrumbwithTimestamp:breadcrumb.timestamp
                           category:@"ui.tap"
                            message:message
                              level:breadcrumb.level
                               data:breadcrumb.data];
}

- (id<SentryRRWebEvent> _Nullable)convertNavigation:
    (SentryBreadcrumb *_Nonnull)breadcrumb {
  NSNumber *startTimestamp =
      [breadcrumb.data[@"start_timestamp"] isKindOfClass:[NSNumber class]]
          ? breadcrumb.data[@"start_timestamp"]
          : nil;
  NSNumber *endTimestamp =
      [breadcrumb.data[@"end_timestamp"] isKindOfClass:[NSNumber class]]
          ? breadcrumb.data[@"end_timestamp"]
          : nil;
  NSString *url = [breadcrumb.data[@"url"] isKindOfClass:[NSString class]]
                      ? breadcrumb.data[@"url"]
                      : nil;

  if (startTimestamp == nil || endTimestamp == nil || url == nil) {
    return nil;
  }

  NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
  if ([breadcrumb.data[@"method"] isKindOfClass:[NSString class]]) {
    data[@"method"] = breadcrumb.data[@"method"];
  }
  if ([breadcrumb.data[@"status_code"] isKindOfClass:[NSNumber class]]) {
    data[@"statusCode"] = breadcrumb.data[@"status_code"];
  }
  if ([breadcrumb.data[@"request_body_size"] isKindOfClass:[NSNumber class]]) {
    data[@"requestBodySize"] = breadcrumb.data[@"request_body_size"];
  }
  if ([breadcrumb.data[@"response_body_size"] isKindOfClass:[NSNumber class]]) {
    data[@"responseBodySize"] = breadcrumb.data[@"response_body_size"];
  }

  return [SentrySessionReplayIntegration
      createNetworkBreadcrumbWithTimestamp:
          [NSDate
              dateWithTimeIntervalSince1970:(startTimestamp.doubleValue / 1000)]
                              endTimestamp:[NSDate
                                               dateWithTimeIntervalSince1970:
                                                   (endTimestamp.doubleValue /
                                                    1000)]
                                 operation:@"resource.http"
                               description:url
                                      data:data];
}

@end

#endif
