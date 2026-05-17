#import "AdvancedShareIntent.h"

#import <MobileCoreServices/MobileCoreServices.h>
#import <React/RCTConvert.h>
#import <UIKit/UIKit.h>

static NSString *const AdvancedShareIntentEventName = @"AdvancedShareIntentReceived";
static NSString *const AdvancedShareIntentDefaultsKey = @"AdvancedShareIntentPayload";
static NSString *const AdvancedShareIntentAppGroupKey = @"AdvancedShareIntentAppGroupIdentifier";
static NSString *const AdvancedShareIntentContainingAppSchemeKey = @"AdvancedShareIntentContainingAppScheme";

@interface AdvancedShareIntent ()
@property (nonatomic, assign) BOOL hasListeners;
@property (nonatomic, copy, nullable) NSDictionary *initialPayload;
@property (nonatomic, copy, nullable) NSString *appGroupIdentifier;
@property (nonatomic, copy, nullable) NSString *containingAppScheme;
@end

@implementation AdvancedShareIntent

RCT_EXPORT_MODULE(AdvancedShareIntent)

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

- (instancetype)init
{
  if ((self = [super init])) {
    _appGroupIdentifier = [[NSUserDefaults standardUserDefaults] stringForKey:AdvancedShareIntentAppGroupKey];
    _containingAppScheme = [[NSUserDefaults standardUserDefaults] stringForKey:AdvancedShareIntentContainingAppSchemeKey];
    _initialPayload = [self readPayloadWithInitial:YES];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
  }

  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSArray<NSString *> *)supportedEvents
{
  return @[AdvancedShareIntentEventName];
}

- (void)startObserving
{
  self.hasListeners = YES;
  NSDictionary *payload = [self readPayloadWithInitial:NO];
  if (payload != nil) {
    [self sendEventWithName:AdvancedShareIntentEventName body:payload];
  }
}

- (void)stopObserving
{
  self.hasListeners = NO;
}

RCT_REMAP_METHOD(getInitialShare,
                 getInitialShareWithResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  NSDictionary *payload = self.initialPayload ?: [self readPayloadWithInitial:YES];
  self.initialPayload = payload;
  resolve(payload ?: nil);
}

RCT_REMAP_METHOD(clearSharedData,
                 clearSharedDataWithResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  self.initialPayload = nil;
  NSUserDefaults *defaults = [self sharedDefaults];
  [defaults removeObjectForKey:AdvancedShareIntentDefaultsKey];
  [defaults synchronize];
  [self removeSharedFiles];
  resolve(nil);
}

RCT_REMAP_METHOD(setAppGroupIdentifier,
                 setAppGroupIdentifier:(NSString *)identifier
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  self.appGroupIdentifier = identifier;
  [[NSUserDefaults standardUserDefaults] setObject:identifier forKey:AdvancedShareIntentAppGroupKey];
  [[NSUserDefaults standardUserDefaults] synchronize];
  self.initialPayload = [self readPayloadWithInitial:YES];
  resolve(nil);
}

RCT_REMAP_METHOD(setContainingAppScheme,
                 setContainingAppScheme:(NSString *)scheme
                 schemeResolver:(RCTPromiseResolveBlock)resolve
                 schemeRejecter:(RCTPromiseRejectBlock)reject)
{
  self.containingAppScheme = scheme;
  [[NSUserDefaults standardUserDefaults] setObject:scheme forKey:AdvancedShareIntentContainingAppSchemeKey];
  [[NSUserDefaults standardUserDefaults] synchronize];
  resolve(nil);
}

- (void)applicationDidBecomeActive
{
  if (!self.hasListeners) {
    return;
  }

  NSDictionary *payload = [self readPayloadWithInitial:NO];
  if (payload != nil) {
    [self sendEventWithName:AdvancedShareIntentEventName body:payload];
  }
}

- (NSUserDefaults *)sharedDefaults
{
  if (self.appGroupIdentifier.length > 0) {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:self.appGroupIdentifier];
    if (defaults != nil) {
      return defaults;
    }
  }

  return [NSUserDefaults standardUserDefaults];
}

- (NSDictionary *)readPayloadWithInitial:(BOOL)isInitial
{
  NSUserDefaults *defaults = [self sharedDefaults];
  NSDictionary *storedPayload = [defaults dictionaryForKey:AdvancedShareIntentDefaultsKey];
  if (storedPayload == nil) {
    return nil;
  }

  NSMutableDictionary *payload = [storedPayload mutableCopy];
  payload[@"isInitial"] = @(isInitial);
  if (payload[@"files"] == nil) {
    payload[@"files"] = @[];
  }
  if (payload[@"receivedAt"] == nil) {
    payload[@"receivedAt"] = @([[NSDate date] timeIntervalSince1970] * 1000);
  }

  return payload;
}

- (NSString *)classifyMimeType:(NSString *)mimeType
{
  if ([mimeType hasPrefix:@"image/"] || [mimeType hasPrefix:@"public.image"]) {
    return @"image";
  }
  if ([mimeType hasPrefix:@"video/"] || [mimeType hasPrefix:@"public.movie"]) {
    return @"video";
  }
  if ([mimeType hasPrefix:@"text/"]) {
    return @"text";
  }
  if ([mimeType isEqualToString:@"photos/asset"]) {
    return @"image";
  }
  return @"document";
}

- (void)removeSharedFiles
{
  if (self.appGroupIdentifier.length == 0) {
    return;
  }

  NSURL *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:self.appGroupIdentifier];
  NSURL *directoryURL = [containerURL URLByAppendingPathComponent:@"AdvancedShareIntent" isDirectory:YES];
  if (directoryURL != nil) {
    [[NSFileManager defaultManager] removeItemAtURL:directoryURL error:nil];
  }
}

@end
