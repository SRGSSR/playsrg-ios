//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "PushService.h"

#import "ApplicationConfiguration.h"
#import "ApplicationSettings.h"
#import "Favorite+Private.h"
#import "PlayAppDelegate.h"
#import "Notification.h"

#import <libextobjc/libextobjc.h>
#import <UrbanAirship-iOS-SDK/AirshipKit.h>
#import <UserNotifications/UserNotifications.h>

NSString * const PushServiceSubscriptionStateDidChangeNotification = @"PushServiceSubscriptionStateDidChangeNotification";
NSString * const PushServiceSubscriptionObjectKey = @"PushServiceSubscriptionObject";
NSString * const PushServiceSubscriptionStateKey = @"PushServiceSubscriptionState";

NSString * const PushServiceDidReceiveNotification = @"PushServiceDidReceiveNotification";

@interface PushService () <UAPushNotificationDelegate>

@property (nonatomic, readonly) NSString *appIdentifier;
@property (nonatomic, readonly) NSString *environmentIdentifier;

@property (nonatomic) UAConfig *configuration;

@end

@implementation PushService

#pragma mark Class methods

+ (PushService *)sharedService
{
    static dispatch_once_t s_onceToken;
    static PushService *s_pushService;
    dispatch_once(&s_onceToken, ^{
        s_pushService = [[PushService alloc] init];
    });
    return s_pushService;
}

#pragma mark Object lifecycle

- (instancetype)init
{
    if (self = [super init]) {
        static NSDictionary<NSNumber *, NSString *>  *s_appIdentifiers;
        static dispatch_once_t s_onceToken;
        dispatch_once(&s_onceToken, ^{
            s_appIdentifiers = @{ @(SRGVendorRSI) : @"playrsi",
                                  @(SRGVendorRTR) : @"playrtr",
                                  @(SRGVendorRTS) : @"playrts",
                                  @(SRGVendorSRF) : @"playsrf",
                                  @(SRGVendorSWI) : @"playswi" };
        });
        _appIdentifier = s_appIdentifiers[@(ApplicationConfiguration.sharedApplicationConfiguration.vendor)];
        if (! _appIdentifier) {
            return nil;
        }
        
        NSString *configurationFilePath = [NSBundle.mainBundle pathForResource:@"AirshipConfig" ofType:@"plist"];
        if (! configurationFilePath) {
            return nil;
        }
        
        UAConfig *configuration = [UAConfig configWithContentsOfFile:configurationFilePath];
        if (! [configuration validate]) {
            return nil;
        }
        
        self.configuration = configuration;
    }
    return self;
}

#pragma mark Getters and Setters

- (NSString *)environmentIdentifier
{
    NSString *environmentIdentifier = @"prod";
#if defined(DEBUG) || defined(NIGHTLY) || defined(BETA)
    NSArray<NSString *> *hostSubDomains = [ApplicationSettingServiceURL().host componentsSeparatedByString:@"."];
    if (hostSubDomains.count == 3) {
        if ([hostSubDomains.firstObject isEqualToString:@"il"]) {
            environmentIdentifier = @"prod";
        }
        else if ([hostSubDomains.firstObject isEqualToString:@"il-stage"]) {
            environmentIdentifier = @"stage";
        }
        else if ([hostSubDomains.firstObject isEqualToString:@"il-test"]) {
            environmentIdentifier = @"test";
        }
        else if ([hostSubDomains.firstObject isEqualToString:@"play-mmf"]) {
            environmentIdentifier = @"mmf";
        }
        else {
            environmentIdentifier = @"prod";
        }
    }
    if (hostSubDomains.count == 4
            && [hostSubDomains.firstObject isEqualToString:@"intlayer"]
            && [hostSubDomains[2] isEqualToString:@"srf"]
            && [hostSubDomains.lastObject isEqualToString:@"ch"]) {
        if ([hostSubDomains[1] isEqualToString:@"production"]) {
            environmentIdentifier = @"prod";
        }
        else if ([hostSubDomains[1] isEqualToString:@"stage"]) {
            environmentIdentifier = @"stage";
        }
        else if ([hostSubDomains[1] isEqualToString:@"test"]) {
            environmentIdentifier = @"test";
        }
        else {
            environmentIdentifier = @"prod";
        }
    }
#endif
    return environmentIdentifier;
}

- (NSArray<NSString *> *)subscribedShowURNs
{
    if (! self.enabled) {
        return @[];
    }
    
    NSMutableArray<NSString *> *URNs = [NSMutableArray array];
    
    NSArray<NSString *> *tags = [UAirship push].tags;
    if (tags.count == 0) {
        return @[];
    }
    
    for (NSString *tag in tags) {
        NSString *URN = [self showURNFromTag:tag];
        if (URN) {
            [URNs addObject:URN];
        }
    }
    
    return [URNs copy];
}

- (BOOL)isEnabled
{
    // iOS 10 and above: Even if alerts have been disabled by the user, `UIApplication.registeredForRemoteNotifications`
    // will still return `YES` if the target supports silent notifications (introduced with iOS 10 rich notifications).
    // We nust retrieve the proper authorization status from iOS 10 `UNUserNotificationCenter`, providing finer-grained
    // information covering these new use cases.
    if (@available(iOS 10, *)) {
        // Make asynchronous call synchronous
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        __block UNNotificationSettings *notificationSettings = nil;
        [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
            notificationSettings = settings;
            dispatch_semaphore_signal(semaphore);
        }];
        
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        return notificationSettings.authorizationStatus == UNAuthorizationStatusAuthorized;
    }
    // Before iOS 10: `UIApplication.registeredForRemoteNotifications` accurately reflects whether the user has authorized
    // notificartions or not.
    else {
        return UIApplication.sharedApplication.currentUserNotificationSettings.types != UIUserNotificationTypeNone;
    }
}

#pragma mark Setup

- (void)setup
{
    [UAirship takeOff:self.configuration];
    if (@available(iOS 10, *)) {
        [UAirship push].defaultPresentationOptions = (UNNotificationPresentationOptionAlert | UNNotificationPresentationOptionBadge | UNNotificationPresentationOptionSound);
    }
    [UAirship push].pushNotificationDelegate = self;
    [UAirship push].autobadgeEnabled = YES;
    
    [[UAirship inAppMessageManager] setEnabled:NO];
}

#pragma mark Badge management

- (void)resetApplicationBadge
{
    [[UAirship push] resetBadge];
}

- (void)updateApplicationBadge
{
    NSInteger unreadNotificationCount = Notification.unreadNotifications.count;
    
    if (UIApplication.sharedApplication.applicationIconBadgeNumber > unreadNotificationCount) {
        [[UAirship push] setBadgeNumber:unreadNotificationCount];
    }
}

#pragma mrk Subscription management

- (NSString *)pushTagForURN:(NSString *)URN
{
    return [NSString stringWithFormat:@"%@|%@|%@|%@", self.appIdentifier, NotificationTypeString(NotificationTypeNewOnDemandContentAvailable), self.environmentIdentifier, URN];
}

- (NSString *)localTagForURN:(NSString *)URN
{
    return [NSString stringWithFormat:@"%@|%@|%@|%@", self.appIdentifier, NotificationTypeString(NotificationTypeLocalNewOnDemandContentAvailable), self.environmentIdentifier, URN];
}

- (NSString *)pushTagForShow:(SRGShow *)show
{
    return [self pushTagForURN:show.URN];
}

- (NSString *)localTagForShow:(SRGShow *)show
{
    return [self localTagForURN:show.URN];
}

- (NSString *)showURNFromTag:(NSString *)tag
{
    NSArray<NSString *> *components = [tag componentsSeparatedByString:@"|"];
    if (components.count < 4) {
        return nil;
    }
    
    if (! [components[1] isEqualToString:NotificationTypeString(NotificationTypeNewOnDemandContentAvailable)]
        && ! [components[1] isEqualToString:NotificationTypeString(NotificationTypeLocalNewOnDemandContentAvailable)] ) {
        return nil;
    }
    
    if (! [components[2] isEqualToString:self.environmentIdentifier]) {
        return nil;
    }
    
    return components[3];
}

- (BOOL)subscribeNotificationToShow:(SRGShow *)show
{
    if (! self.enabled || ! show) {
        return NO;
    }
    
    [[UAirship push] removeTag:[self localTagForShow:show]];
    [[UAirship push] addTag:[self pushTagForShow:show]];
    [[UAirship push] updateRegistration];
    
    [NSNotificationCenter.defaultCenter postNotificationName:PushServiceSubscriptionStateDidChangeNotification
                                                      object:self
                                                    userInfo:@{ PushServiceSubscriptionObjectKey : show,
                                                                PushServiceSubscriptionStateKey : @YES }];
    
    return YES;
}

- (BOOL)subscribeToShow:(SRGShow *)show
{
    if (! show) {
        return NO;
    }
    
    [[UAirship push] removeTag:[self pushTagForShow:show]];
    [[UAirship push] addTag:[self localTagForShow:show]];
    [[UAirship push] updateRegistration];
    
    [NSNotificationCenter.defaultCenter postNotificationName:PushServiceSubscriptionStateDidChangeNotification
                                                      object:self
                                                    userInfo:@{ PushServiceSubscriptionObjectKey : show,
                                                                PushServiceSubscriptionStateKey : @YES }];
    
    return YES;
}

- (BOOL)subscribeToShowURN:(NSString *)showURN
{
    if (! showURN) {
        return NO;
    }
    NSArray *tags1 = [UAirship push].tags;
    [[UAirship push] removeTag:[self pushTagForURN:showURN]];
    [[UAirship push] addTag:[self localTagForURN:showURN]];
    NSArray *tags2 = [UAirship push].tags;
    [[UAirship push] updateRegistration];
    NSArray *tags3 = [UAirship push].tags;
    
    return YES;
}

- (BOOL)toggleSubscriptionForShow:(SRGShow *)show
{
    if ([self isSubscribedToShow:show]) {
        return [self unsubscribeFromShow:show];
    }
    else {
        return [self subscribeToShow:show];
    }
}

- (BOOL)togglePushNotificationForShow:(SRGShow *)show
{
    if ([self isPushNotificationSubscribedToShow:show]) {
        return [self subscribeToShow:show];
    }
    else {
        return [self subscribeNotificationToShow:show];
    }
}

- (BOOL)unsubscribeFromShow:(SRGShow *)show
{
    if (! show) {
        return NO;
    }
    
    [[UAirship push] removeTag:[self localTagForShow:show]];
    [[UAirship push] removeTag:[self pushTagForShow:show]];
    [[UAirship push] updateRegistration];
    
    [NSNotificationCenter.defaultCenter postNotificationName:PushServiceSubscriptionStateDidChangeNotification
                                                      object:self
                                                    userInfo:@{ PushServiceSubscriptionObjectKey : show,
                                                                PushServiceSubscriptionStateKey : @NO }];
    return YES;
}

- (BOOL)isSubscribedToShow:(SRGShow *)show
{
    if (! show) {
        return NO;
    }
    
    return [[UAirship push].tags containsObject:[self localTagForShow:show]] || [[UAirship push].tags containsObject:[self pushTagForShow:show]];
}

- (BOOL)isPushNotificationSubscribedToShow:(SRGShow *)show
{
    if (! show) {
        return NO;
    }
    
    return [[UAirship push].tags containsObject:[self pushTagForShow:show]];
}

#pragma mark Actions

- (BOOL)presentSystemAlertForPushNotifications
{
    // Lazily enable push notifications at the Urban Airship level, so that the user is asked the first time she
    // attempts to use the functionality.
    if (! [UAirship push].userPushNotificationsEnabled) {
        [UAirship push].userPushNotificationsEnabled = YES;
        return YES;
    }
    else {
        return NO;
    }
}

#pragma mark UAPushNotificationDelegate protocol

- (void)receivedNotificationResponse:(UANotificationResponse *)notificationResponse completionHandler:(void (^)(void))completionHandler
{
    if (@available(iOS 10, *)) {
        if (notificationResponse.notificationContent.notification) {
            Notification *notification = [[Notification alloc] initWithNotification:notificationResponse.notificationContent.notification];
            [Notification saveNotification:notification read:YES];
        }
    }
    
    UANotificationContent *notificationContent = notificationResponse.notificationContent;
    
    NSString *channelUid = notificationContent.notificationInfo[@"channelId"];
    
    if (notificationContent.notificationInfo[@"media"]) {
        NSString *mediaURN = notificationContent.notificationInfo[@"media"];
        UIApplication *application = UIApplication.sharedApplication;
        PlayAppDelegate *appDelegate = (PlayAppDelegate *)application.delegate;
        [appDelegate openMediaWithURN:mediaURN channelUid:channelUid fromPushNotification:YES completionBlock:^{
            SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
            labels.source = notificationContent.notificationInfo[@"show"] ?: AnalyticsSourceNotificationPush;
            labels.type = notificationContent.notificationInfo[@"type"] ?: AnalyticsTypeActionPlayMedia;
            labels.value = mediaURN;
            [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleNotificationPushOpen labels:labels];
        }];
    }
    else if (notificationContent.notificationInfo[@"show"]) {
        NSString *showURN = notificationContent.notificationInfo[@"show"];
        UIApplication *application = UIApplication.sharedApplication;
        PlayAppDelegate *appDelegate = (PlayAppDelegate *)application.delegate;
        [appDelegate openShowWithURN:showURN channelUid:channelUid fromPushNotification:YES completionBlock:^{
            SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
            labels.source = AnalyticsSourceNotificationPush;
            labels.type = notificationContent.notificationInfo[@"type"] ?: AnalyticsTypeActionDisplayShow;
            labels.value = showURN;
            [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleNotificationPushOpen labels:labels];
        }];
    }
    else {
        SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
        labels.source = AnalyticsSourceNotificationPush;
        labels.type = notificationContent.notificationInfo[@"type"] ?: AnalyticsTypeActionNotificationAlert;
        labels.value = notificationContent.alertBody;
        [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleNotificationPushOpen labels:labels];
    }
    completionHandler();
}

- (void)receivedForegroundNotification:(UANotificationContent *)notificationContent completionHandler:(void (^)(void))completionHandler
{
    if (@available(iOS 10, *)) {
        if (notificationContent.notification) {
            Notification *notification = [[Notification alloc] initWithNotification:notificationContent.notification];
            [Notification saveNotification:notification read:NO];
        }
    }
    [NSNotificationCenter.defaultCenter postNotificationName:PushServiceDidReceiveNotification object:self];
    completionHandler();
}

- (void)receivedBackgroundNotification:(UANotificationContent *)notificationContent completionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    if (@available(iOS 10, *)) {
        if (notificationContent.notification) {
            Notification *notification = [[Notification alloc] initWithNotification:notificationContent.notification];
            [Notification saveNotification:notification read:NO];
        }
    }
    [NSNotificationCenter.defaultCenter postNotificationName:PushServiceDidReceiveNotification object:self];
    completionHandler(UIBackgroundFetchResultNewData);
}

@end

@implementation PushService (Helpers)

- (BOOL)toggleSubscriptionForShow:(SRGShow *)show inView:(UIView *)view
{
    return [self toggleSubscriptionForShow:show inViewController:view.nearestViewController];
}

- (BOOL)toggleSubscriptionForShow:(SRGShow *)show inViewController:(UIViewController *)viewController
{
    return [self toggleSubscriptionForShow:show];
}

- (BOOL)togglePushNotificationForShow:(SRGShow *)show inView:(UIView *)view
{
    return [self togglePushNotificationForShow:show inViewController:view.nearestViewController];
}

- (BOOL)togglePushNotificationForShow:(SRGShow *)show inViewController:(UIViewController *)viewController
{
    if (! [self togglePushNotificationForShow:show]) {
        if (! [self presentSystemAlertForPushNotifications]) {
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Enable notifications?", @"Question displayed at the top of an alert asking the user to enable notifications")
                                                                                     message:NSLocalizedString(@"For the application to inform you when a new episode is available, notifications must be enabled.", @"Explanation displayed in the alert asking the user to enable notifications")
                                                                              preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Enable in system settings", @"Title of a button to propose the user to enable notifications in the system settings") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                NSURL *URL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                [UIApplication.sharedApplication openURL:URL];
            }]];
            [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Title of a cancel button") style:UIAlertActionStyleDefault handler:nil]];
            [viewController presentViewController:alertController animated:YES completion:nil];
        }
        return NO;
    }
    
    return YES;
}

- (void)migrate
{
    NSArray<Favorite *> *favorites = [Favorite showFavorites];
    if (favorites.count) {
        NSArray<NSString *> *subscribedShowURNs = self.subscribedShowURNs;
        for (Favorite *favorite in favorites) {
            if (favorite.showURN && ! [subscribedShowURNs containsObject:favorite.showURN]) {
                [self subscribeToShowURN:favorite.showURN];
            }
        }
        [Favorite finishMigrationForFavorites:favorites];
    }
}

@end
