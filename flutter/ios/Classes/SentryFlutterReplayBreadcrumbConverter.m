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

  if (breadcrumb.category == nil
      // Do not add Sentry Event breadcrumbs to replay
      || [breadcrumb.category isEqualToString:@"sentry.event"] ||
      [breadcrumb.category isEqualToString:@"sentry.transaction"]) {
    return nil;
  }

  if ([breadcrumb.category isEqualToString:@"http"]) {
    return [self convertNetwork:breadcrumb];
  }

  if ([breadcrumb.category isEqualToString:@"navigation"]) {
    return [self convertFrom:breadcrumb withCategory:nil andMessage:nil];
  }

  if ([breadcrumb.category isEqualToString:@"ui.click"]) {
    return [self convertFrom:breadcrumb
                withCategory:@"ui.tap"
                  andMessage:[self getTouchPathMessage:breadcrumb.data[@"path"]]];
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

- (id<SentryRRWebEvent> _Nullable)convertFrom:
                                      (SentryBreadcrumb *_Nonnull)breadcrumb
                                 withCategory:(NSString *)category
                                   andMessage:(NSString *)message {
  return [SentrySessionReplayIntegration
      createBreadcrumbwithTimestamp:breadcrumb.timestamp
                           category:category ?: breadcrumb.category
                            message:message ?: breadcrumb.message
                              level:breadcrumb.level
                               data:breadcrumb.data];
}

- (id<SentryRRWebEvent> _Nullable)convertNetwork:
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
      createNetworkBreadcrumbWithTimestamp:[self dateFrom:startTimestamp]
                              endTimestamp:[self dateFrom:endTimestamp]
                                 operation:@"resource.http"
                               description:url
                                      data:data];
}

- (NSDate *_Nonnull)dateFrom:(NSNumber *_Nonnull)timestamp {
  return [NSDate dateWithTimeIntervalSince1970:(timestamp.doubleValue / 1000)];
}

- (NSString * _Nullable)getTouchPathMessage:(id _Nullable)maybePath {
    if (![maybePath isKindOfClass:[NSArray class]]) {
        return nil;
    }

    NSArray *path = (NSArray *)maybePath;
    if (path.count == 0) {
        return nil;
    }

    NSMutableString *message = [NSMutableString string];
    for (NSInteger i = MIN(3, path.count - 1); i >= 0; i--) {
        id item = path[i];
        if (![item isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        NSDictionary *itemDict = (NSDictionary *)item;
        [message appendString:itemDict[@"element"] ?: @"?"];

        id identifier = itemDict[@"label"] ?: itemDict[@"name"];
        if ([identifier isKindOfClass:[NSString class]] && [(NSString *)identifier length] > 0) {
            NSString *identifierStr = (NSString *)identifier;
            if (identifierStr.length > 20) {
                identifierStr = [[identifierStr substringToIndex:17] stringByAppendingString:@"..."];
            }
            [message appendFormat:@"(%@)", identifierStr];
        }

        if (i > 0) {
            [message appendString:@" > "];
        }
    }

    return message.length > 0 ? message : nil;
}
@end

#endif
