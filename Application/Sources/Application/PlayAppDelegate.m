//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "PlayAppDelegate.h"

#import "ApplicationConfiguration.h"
#import "ApplicationSettings.h"
#import "Banner.h"
#import "CalendarViewController.h"
#import "DeeplinkService.h"
#import "Download.h"
#import "Favorites.h"
#import "GoogleCast.h"
#import "History.h"
#import "HomeTopicViewController.h"
#import "MediaPlayerViewController.h"
#import "ModuleViewController.h"
#import "NavigationController.h"
#import "PlayApplication.h"
#import "PlayErrors.h"
#import "Playlist.h"
#import "PlayLogger.h"
#import "Play-Swift-Bridge.h"
#import "PushService.h"
#import "ShowViewController.h"
#import "ShowsViewController.h"
#import "UIApplication+PlaySRG.h"
#import "UIImage+PlaySRG.h"
#import "UIViewController+PlaySRG.h"
#import "UIWindow+PlaySRG.h"
#import "UpdateInfo.h"
#import "WatchLater.h"
#import "WebViewController.h"

#import <AVFoundation/AVFoundation.h>
#import <Firebase/Firebase.h>
#import <libextobjc/libextobjc.h>
#import <Mantle/Mantle.h>
#import <SafariServices/SafariServices.h>
#import <SRGAnalytics_Identity/SRGAnalytics_Identity.h>
#import <SRGDataProvider/SRGDataProvider.h>
#import <SRGIdentity/SRGIdentity.h>
#import <SRGLetterbox/SRGLetterbox.h>
#import <SRGUserData/SRGUserData.h>
#import <UrbanAirship-iOS-SDK/AirshipKit.h>

#if defined(DEBUG) || defined(NIGHTLY) || defined(BETA)
#import <Fingertips/Fingertips.h>
#endif

// ** Private SRGLetterbox setter for DRM slow rollout.
// TODO: Remove in 2019

@interface SRGLetterboxController (Private_SRGLetterbox)

@property (class, nonatomic) BOOL prefersDRM;

@end

// **

static void *s_kvoContext = &s_kvoContext;

static MenuItemInfo *MenuItemInfoForChannelUid(NSString *channelUid);

@implementation PlayAppDelegate

#pragma mark Getters and setters

- (SideMenuController *)sideMenuController
{
    return (SideMenuController *)self.window.rootViewController;
}

#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    ApplicationConfiguration *applicationConfiguration = ApplicationConfiguration.sharedApplicationConfiguration;
    
    // TODO: Remove in 2019 when DRMs are widely available
    [SRGLetterboxController setPrefersDRM:applicationConfiguration.prefersDRM];
    
    // The configuration file, copied at build time in the main product bundle, will have the standard Firebase
    // configuration filename
    if ([NSBundle.mainBundle pathForResource:@"GoogleService-Info" ofType:@"plist"]) {
        [FIRApp configure];
    }
    
    NSURL *identityWebserviceURL = applicationConfiguration.identityWebserviceURL;
    NSURL *identityWebsiteURL = applicationConfiguration.identityWebsiteURL;
    if (identityWebserviceURL && identityWebsiteURL) {
        SRGIdentityService.currentIdentityService = [[SRGIdentityService alloc] initWithWebserviceURL:identityWebserviceURL websiteURL:identityWebsiteURL];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(userDidCancelLogin:)
                                                   name:SRGIdentityServiceUserDidCancelLoginNotification
                                                 object:SRGIdentityService.currentIdentityService];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(userDidLogin:)
                                                   name:SRGIdentityServiceUserDidLoginNotification
                                                 object:SRGIdentityService.currentIdentityService];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(didUpdateAccount:)
                                                   name:SRGIdentityServiceDidUpdateAccountNotification
                                                 object:SRGIdentityService.currentIdentityService];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(userDidLogout:)
                                                   name:SRGIdentityServiceUserDidLogoutNotification
                                                 object:SRGIdentityService.currentIdentityService];
    }
    
    NSURL *storeFileURL = [HLSApplicationLibraryDirectoryURL() URLByAppendingPathComponent:@"PlayData.sqlite"];
    SRGUserData.currentUserData = [[SRGUserData alloc] initWithStoreFileURL:storeFileURL
                                                                 serviceURL:applicationConfiguration.userDataServiceURL
                                                            identityService:SRGIdentityService.currentIdentityService];
    
    GoogleCastSetup();
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(playbackDidContinueAutomatically:)
                                               name:SRGLetterboxPlaybackDidContinueAutomaticallyNotification
                                             object:nil];
    
#if defined(DEBUG) || defined(NIGHTLY) || defined(BETA)
    self.window = [[MBFingerTipWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
#else
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
#endif
    
    self.window.backgroundColor = UIColor.blackColor;
    
    if (@available(iOS 11, *)) {
        self.window.accessibilityIgnoresInvertColors = YES;
    }
    
    [self setupAnalytics];
    [self setupDataProvider];
    
    // Letterbox service setup for picture and picture
    SRGLetterboxService.sharedService.mirroredOnExternalScreen = ApplicationSettingPresenterModeEnabled();
    // Use appropriate voice over language for the whole application
    application.accessibilityLanguage = applicationConfiguration.voiceOverLanguageCode;
#if defined(DEBUG) || defined(NIGHTLY) || defined(BETA)
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults addObserver:self forKeyPath:PlaySRGSettingServiceURL options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld  context:s_kvoContext];
    [defaults addObserver:self forKeyPath:PlaySRGSettingUserLocation options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:s_kvoContext];
#endif
    
    // Various setups
#ifndef DEBUG
    [self setupHockey];
#endif
    
    // Clean downloaded folder
    [Download removeUnusedDownloadedFiles];
    
    // Setup view controller hierarchy
    self.window.rootViewController = [[SideMenuController alloc] init];
    [self.window makeKeyAndVisible];
    
    [self checkForForcedUpdates];
    
    // Processes run once in the lifetime of the application
    __block BOOL firstLaunchDone = YES;
    PlayApplicationRunOnce(^(void (^completionHandler)(BOOL success)) {
        firstLaunchDone = NO;
        completionHandler(YES);
    }, @"FirstLaunchDone", nil);
    
    // Migrate the latest radio live uid to URN
    NSString *oldSettingLatestPlayedRadioLiveUid = [NSUserDefaults.standardUserDefaults stringForKey:@"PlaySRGSettingLatestPlayedRadioLiveUid"];
    if (oldSettingLatestPlayedRadioLiveUid) {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:@"PlaySRGSettingLatestPlayedRadioLiveUid"];
        [NSUserDefaults.standardUserDefaults synchronize];
        
        static dispatch_once_t s_onceToken;
        static NSDictionary<NSNumber *, NSString *> *s_BUs;
        dispatch_once(&s_onceToken, ^{
            s_BUs = @{ @(SRGVendorRSI) : @"rsi",
                       @(SRGVendorRTR) : @"rtr",
                       @(SRGVendorRTS) : @"rts",
                       @(SRGVendorSRF) : @"srf",
                       @(SRGVendorSWI) : @"swi" };
        });
        SRGVendor vendor = ApplicationConfiguration.sharedApplicationConfiguration.vendor;
        NSString *bu = s_BUs[@(vendor)];
        if (bu) {
            NSString *urn = [NSString stringWithFormat:@"urn:%@:audio:%@", bu, oldSettingLatestPlayedRadioLiveUid];
            [NSUserDefaults.standardUserDefaults setObject:urn forKey:PlaySRGSettingLastPlayedRadioLiveURN];
        }
        [NSUserDefaults.standardUserDefaults synchronize];
    }
    
    [PushService.sharedService setup];
    [self updateApplicationBadge];
    FavoritesSetup();
    
    // Local objects migration
    WatchLaterMigrate();
    FavoritesMigrate();
    
    [self showNextAvailableOnboarding];
    
    NSURL *whatsNewURL = applicationConfiguration.whatsNewURL;
    PlayApplicationRunOnce(^(void (^completionHandler)(BOOL success)) {
        // Only display the "What's new" popup for application updates, not after the application installation
        if (firstLaunchDone) {
            [self loadWhatsNewWithCompletionHandler:^(UIViewController * _Nullable viewController, NSError * _Nullable error) {
                if (error) {
                    completionHandler(NO);
                    return;
                }
                
                viewController.title = NSLocalizedString(@"What's new", @"Title displayed at the top of the What's new view");
                viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Close", nil)
                                                                                                   style:UIBarButtonItemStyleDone
                                                                                                  target:self
                                                                                                  action:@selector(closeWhatsNew:)];
                
                NavigationController *navigationController = [[NavigationController alloc] initWithRootViewController:viewController];
                [self.window.play_topViewController presentViewController:navigationController animated:YES completion:^{
                    completionHandler(YES);
                }];
            }];
        }
        else {
            completionHandler(YES);
        }
    }, @"LastWhatsNewURLRead", whatsNewURL.absoluteString);
    
    // Open the application via 3D touch shortcut if needed
    BOOL shouldNotPerformAdditionalDelegateHandling = YES;
    UIApplicationShortcutItem *launchedShortcutItem = launchOptions[UIApplicationLaunchOptionsShortcutItemKey];
    if (launchedShortcutItem) {
        shouldNotPerformAdditionalDelegateHandling = NO;
        [self handleShortcutItem:launchedShortcutItem];
    }
    
    return shouldNotPerformAdditionalDelegateHandling;
}

// Quick Actions with 3D Touch
- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^ _Nonnull)(BOOL succeeded))completionHandler
{
    BOOL handledShortcutItem = [self handleShortcutItem:shortcutItem];
    completionHandler(handledShortcutItem);
}

// Open [scheme]://open?media=[media_urn] (optional query parameters: channel-id=[channel_id], start-time=[start_position_seconds])
// Open [scheme]://open?show=[show_urn] (optional query parameter: channel-id=[channel_id])
// Open [scheme]://open?page=[page_urn] (optional query parameters: channel-id=[channel_id], used for radio pages)
// Open [scheme]://open?topic=[topic_urn]
// Open [scheme]://open?module=[module_urn]
// Open [scheme]://[play website url] ("parse_play_url.js" try to transformed to scheme urls)
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)URL options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    AnalyticsSource analyticsSource = ([URL.scheme isEqualToString:@"http"] || [URL.scheme isEqualToString:@"https"]) ? AnalyticsSourceDeeplink : AnalyticsSourceSchemeURL;
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    if (! [URLComponents.host.lowercaseString isEqualToString:@"open"]) {
        NSURL *deeplinkURL = [DeeplinkService.sharedService schemeURLFromWebURL:URL];
        if (deeplinkURL) {
            URLComponents = [NSURLComponents componentsWithURL:deeplinkURL resolvingAgainstBaseURL:NO];
        }
    }
    
    if ([URLComponents.host.lowercaseString isEqualToString:@"open"]) {
        
#if defined(DEBUG) || defined(NIGHTLY) || defined(BETA)
        NSString *server = [self valueFromURLComponents:URLComponents withParameterName:@"server"];
        if (server) {
            NSURL *serviceURL = ApplicationSettingServiceURLForKey(server);
            if (serviceURL && ! [serviceURL isEqual:ApplicationSettingServiceURL()]) {
                ApplicationSettingSetServiceURL(serviceURL);
                
                [Banner showWithStyle:BannerStyleInfo
                              message:[NSString stringWithFormat:NSLocalizedString(@"Server changed to '%@'", @"Notification message when the server URL changed due to a scheme URL."), ApplicationSettingServiceNameForKey(server)]
                                image:[UIImage imageNamed:@"settings-22"]
                               sticky:NO
                     inViewController:nil];
            }
        }
#endif
        
        NSString *channelUid = [self valueFromURLComponents:URLComponents withParameterName:@"channel-id"];
        
        NSString *mediaURN = [self valueFromURLComponents:URLComponents withParameterName:@"media"];
        if (mediaURN) {
            NSInteger startTime = [[self valueFromURLComponents:URLComponents withParameterName:@"start-time"] integerValue];
            [self openMediaWithURN:mediaURN startTime:startTime channelUid:channelUid fromPushNotification:NO completionBlock:^{
                SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
                labels.source = analyticsSource;
                labels.type = AnalyticsTypeActionPlayMedia;
                labels.value = mediaURN;
                labels.extraValue1 = options[UIApplicationOpenURLOptionsSourceApplicationKey];
                [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleOpenURL labels:labels];
            }];
            return YES;
        }
        
        NSString *showURN = [self valueFromURLComponents:URLComponents withParameterName:@"show"];
        if (showURN) {
            [self openShowWithURN:showURN channelUid:channelUid fromPushNotification:NO completionBlock:^{
                SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
                labels.source = analyticsSource;
                labels.type = AnalyticsTypeActionDisplayShow;
                labels.value = showURN;
                labels.extraValue1 = options[UIApplicationOpenURLOptionsSourceApplicationKey];
                [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleOpenURL labels:labels];
            }];
            return YES;
        }
        
        NSString *pageURN = [self valueFromURLComponents:URLComponents withParameterName:@"page"];
        if (pageURN) {
            BOOL canOpen = [self openPageWithURN:pageURN channelUid:channelUid fromPushNotification:NO completionBlock:^{
                SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
                labels.source = analyticsSource;
                labels.type = AnalyticsTypeActionDisplayPage;
                labels.value = pageURN;
                labels.extraValue1 = options[UIApplicationOpenURLOptionsSourceApplicationKey];
                [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleOpenURL labels:labels];
            }];
            
            if (canOpen) {
                return YES;
            }
        }
        
        NSString *topicURN = [self valueFromURLComponents:URLComponents withParameterName:@"topic"];
        if (topicURN) {
            BOOL canOpen = [self openTopicWithURN:topicURN fromPushNotification:NO completionBlock:^{
                SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
                labels.source = analyticsSource;
                labels.type = AnalyticsTypeActionDisplayPage;
                labels.value = topicURN;
                labels.extraValue1 = options[UIApplicationOpenURLOptionsSourceApplicationKey];
                [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleOpenURL labels:labels];
            }];
            
            if (canOpen) {
                return YES;
            }
        }
        
        NSString *moduleURN = [self valueFromURLComponents:URLComponents withParameterName:@"module"];
        if (moduleURN) {
            BOOL canOpen = [self openModuleWithURN:moduleURN fromPushNotification:NO completionBlock:^{
                SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
                labels.source = analyticsSource;
                labels.type = AnalyticsTypeActionDisplayPage;
                labels.value = moduleURN;
                labels.extraValue1 = options[UIApplicationOpenURLOptionsSourceApplicationKey];
                [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleOpenURL labels:labels];
            }];
            
            if (canOpen) {
                return YES;
            }
        }
        
        // TODO: [scheme]://open?date=01-01-2016 … or page urn bydate, az, search …
        
    }
    
    [UIApplication.sharedApplication play_openURL:URL withCompletionHandler:nil];
    
    return NO;
}

// https://support.urbanairship.com/hc/en-us/articles/213492483-iOS-Badging-and-Auto-Badging
- (void)applicationDidBecomeActive:(UIApplication *)application
{
    [self updateApplicationBadge];
}

// https://support.urbanairship.com/hc/en-us/articles/213492483-iOS-Badging-and-Auto-Badging
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(nonnull NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    [self updateApplicationBadge];
    completionHandler(UIBackgroundFetchResultNoData);
}

#pragma mark Custom URL scheme support

- (NSString *)valueFromURLComponents:(NSURLComponents *)URLComponents withParameterName:(NSString *)parameterName
{
    NSParameterAssert(URLComponents);
    NSParameterAssert(parameterName);
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(NSURLQueryItem.new, name), parameterName];
    NSURLQueryItem *queryItem = [URLComponents.queryItems filteredArrayUsingPredicate:predicate].firstObject;
    if (! queryItem) {
        return nil;
    }
    
    return queryItem.value;
}

- (BOOL)openMediaWithURN:(NSString *)mediaURN startTime:(NSInteger)startTime channelUid:(NSString *)channelUid fromPushNotification:(BOOL)fromPushNotification completionBlock:(void (^)(void))completionBlock
{
    NSParameterAssert(mediaURN);
    
    MenuItemInfo *menuItemInfo = MenuItemInfoForChannelUid(channelUid);
    [self resetWithMenuItemInfo:menuItemInfo completionBlock:^{
        CMTime time = (startTime > 0) ? CMTimeMakeWithSeconds(startTime, NSEC_PER_SEC) : kCMTimeZero;
        [self playURN:mediaURN media:nil atPosition:[SRGPosition positionAtTime:time] fromPushNotification:fromPushNotification completion:nil];
        
        // Call completion when the opening process has been initiated
        completionBlock ? completionBlock() : nil;
    }];
    
    return YES;
}

- (BOOL)openShowWithURN:(NSString *)showURN channelUid:(NSString *)channelUid fromPushNotification:(BOOL)fromPushNotification completionBlock:(void (^)(void))completionBlock
{
    NSParameterAssert(showURN);
    
    MenuItemInfo *menuItemInfo = MenuItemInfoForChannelUid(channelUid);
    [self resetWithMenuItemInfo:menuItemInfo completionBlock:^{
        [self openShowURN:showURN show:nil fromPushNotification:fromPushNotification];
        
        // Call completion when the opening process has been initiated
        completionBlock ? completionBlock() : nil;
    }];
    
    return YES;
}

- (BOOL)openPageWithURN:(NSString *)pageURN channelUid:(NSString *)channelUid fromPushNotification:(BOOL)fromPushNotification completionBlock:(void (^)(void))completionBlock
{
    NSParameterAssert(pageURN);
    
    BOOL canOpen = NO;
    
    RadioChannel *radioChannel = [ApplicationConfiguration.sharedApplicationConfiguration radioChannelForUid:channelUid];
    NSString *pageUid = [pageURN componentsSeparatedByString:@":"].lastObject;
    
    MenuItemInfo *menuItemInfo = nil;
    UIViewController *pageViewController = nil;
    if ([pageUid isEqualToString:@"az"]) {
        canOpen = YES;
        // TODO: Support "index" query parameter.
        if ([pageURN containsString:@":radio:"] && !radioChannel) {
            menuItemInfo = [MenuItemInfo menuItemInfoWithMenuItem:MenuItemRadioShowAZ];
        }
        else {
            pageViewController = [[ShowsViewController alloc] initWithRadioChannel:radioChannel];
        }
    }
    else if ([pageUid isEqualToString:@"bydate"]) {
        canOpen = YES;
        // TODO: Support "date" query parameter.
        if ([pageURN containsString:@":radio:"] && !radioChannel) {
            radioChannel = [ApplicationConfiguration.sharedApplicationConfiguration radioChannels].firstObject;
        }
        
        pageViewController = [[CalendarViewController alloc] initWithRadioChannel:radioChannel];
    }
    else if ([pageUid isEqualToString:@"search"]) {
        canOpen = YES;
        // TODO: Support "search" query parameter.
        menuItemInfo = [MenuItemInfo menuItemInfoWithMenuItem:MenuItemSearch];
    }
    else if ([pageUid isEqualToString:@"home"]) {
        canOpen = YES;
        if ([pageURN containsString:@":radio:"] && !radioChannel) {
            radioChannel = [ApplicationConfiguration.sharedApplicationConfiguration radioChannels].firstObject;
        }
    }
    
    if (!menuItemInfo) {
        menuItemInfo = MenuItemInfoForChannelUid(channelUid);
    }
    
    [self resetWithMenuItemInfo:menuItemInfo completionBlock:^{
        if (pageViewController) {
            [self.sideMenuController pushViewController:pageViewController animated:YES];
        }
        
        // Call completion when the opening process has been initiated
        completionBlock ? completionBlock() : nil;
    }];
    
    return canOpen;
}

- (BOOL)openTopicWithURN:(NSString *)topicURN fromPushNotification:(BOOL)fromPushNotification completionBlock:(void (^)(void))completionBlock
{
    NSParameterAssert(topicURN);
    
    MenuItemInfo *menuItemInfo = [MenuItemInfo menuItemInfoWithMenuItem:MenuItemTVOverview];
    [self resetWithMenuItemInfo:menuItemInfo completionBlock:^{
        [self openTopicURN:topicURN fromPushNotification:fromPushNotification];
        
        // Call completion when the opening process has been initiated
        completionBlock ? completionBlock() : nil;
    }];
    
    return YES;
}

- (BOOL)openModuleWithURN:(NSString *)moduleURN fromPushNotification:(BOOL)fromPushNotification completionBlock:(void (^)(void))completionBlock
{
    NSParameterAssert(moduleURN);
    
    MenuItemInfo *menuItemInfo = [MenuItemInfo menuItemInfoWithMenuItem:MenuItemTVOverview];
    [self resetWithMenuItemInfo:menuItemInfo completionBlock:^{
        [self openModuleURN:moduleURN fromPushNotification:fromPushNotification];
        
        // Call completion when the opening process has been initiated
        completionBlock ? completionBlock() : nil;
    }];
    
    return YES;
}

#pragma mark Handoff

- (BOOL)application:(UIApplication *)application willContinueUserActivityWithType:(NSString *)userActivityType
{
    return [userActivityType isEqualToString:[NSBundle.mainBundle.bundleIdentifier stringByAppendingString:@".playing"]]
        || [userActivityType isEqualToString:[NSBundle.mainBundle.bundleIdentifier stringByAppendingString:@".displaying"]]
        || [userActivityType isEqualToString:NSUserActivityTypeBrowsingWeb];
}

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler
{
    if ([userActivity.activityType isEqualToString:[NSBundle.mainBundle.bundleIdentifier stringByAppendingString:@".playing"]]) {
        NSString *mediaURN = userActivity.userInfo[@"URNString"];
        if (mediaURN) {
            SRGMedia *media = [NSKeyedUnarchiver unarchiveObjectWithData:userActivity.userInfo[@"SRGMediaData"]];
            NSNumber *position = [userActivity.userInfo[@"position"] isKindOfClass:NSNumber.class] ? userActivity.userInfo[@"position"] : nil;
            [self playURN:mediaURN media:media atPosition:[SRGPosition positionAtTimeInSeconds:position.integerValue] fromPushNotification:NO completion:nil];
            
            SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
            labels.source = AnalyticsSourceHandoff;
            labels.type = AnalyticsTypeActionPlayMedia;
            labels.value = mediaURN;
            [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleUserActivity labels:labels];
        }
        else {
            NSError *error = [NSError errorWithDomain:PlayErrorDomain
                                                 code:PlayErrorCodeNotFound
                                 localizedDescription:NSLocalizedString(@"The media cannot be opened.", @"Error message when a media cannot be opened via Handoff")];
            [Banner showError:error inViewController:nil];
        }
        
        return (mediaURN != nil);
    }
    else if ([userActivity.activityType isEqualToString:[NSBundle.mainBundle.bundleIdentifier stringByAppendingString:@".displaying"]]) {
        NSString *showURN = userActivity.userInfo[@"URNString"];
        if (showURN) {
            SRGShow *show = [NSKeyedUnarchiver unarchiveObjectWithData:userActivity.userInfo[@"SRGShowData"]];
            MenuItemInfo *menuItemInfo = [MenuItemInfo menuItemInfoWithMenuItem:MenuItemTVOverview];
            [self resetWithMenuItemInfo:menuItemInfo completionBlock:^{
                [self openShowURN:showURN show:show fromPushNotification:NO];
            }];
            
            SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
            labels.source = AnalyticsSourceHandoff;
            labels.type = AnalyticsTypeActionDisplayShow;
            labels.value = showURN;
            [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleUserActivity labels:labels];
        }
        else {
            NSError *error = [NSError errorWithDomain:PlayErrorDomain
                                                 code:PlayErrorCodeNotFound
                                 localizedDescription:NSLocalizedString(@"The show cannot be opened.", @"Error message when a show cannot be opened via Handoff")];
            [Banner showError:error inViewController:nil];
        }
        
        return (showURN != nil);
    }
    else if ([userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
        return [self application:UIApplication.sharedApplication openURL:userActivity.webpageURL options:@{}];
    }
    else {
        return NO;
    }
}

#pragma mark Helpers

- (void)setupHockey
{
    NSString *hockeyIdentifier = [NSBundle.mainBundle objectForInfoDictionaryKey:@"HockeyIdentifier"];
    [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:hockeyIdentifier delegate:self];
    [[BITHockeyManager sharedHockeyManager] startManager];
    
#if defined(BETA) || defined(NIGHTLY)
    [[BITHockeyManager sharedHockeyManager].authenticator authenticateInstallation];
#endif
}

- (void)updateApplicationBadge
{
    if (@available(iOS 10, *)) {
        [PushService.sharedService updateApplicationBadge];
    }
    else {
        [PushService.sharedService resetApplicationBadge];
    }
}

- (void)setupDataProvider
{
    [SRGNetworkActivityManagement enable];
    [UIImage play_setUseOriginalImagesOnly:ApplicationSettingOriginalImagesOnlyEnabled()];
    
    NSURL *serviceURL = ApplicationSettingServiceURL();
    SRGDataProvider *dataProvider = [[SRGDataProvider alloc] initWithServiceURL:serviceURL];
#if defined(DEBUG) || defined(NIGHTLY) || defined(BETA)
    dataProvider.globalParameters = ApplicationSettingGlobalParameters();
    
    NSString *environment = nil;
    
    NSString *host = serviceURL.host;
    if ([host containsString:@"test"]) {
        environment = @"test";
    }
    else if ([host containsString:@"stage"]) {
        environment = @"stage";
    }
    
    if (environment) {
        static dispatch_once_t s_onceToken2;
        static NSDictionary<NSNumber *, NSString *> *s_suffixes;
        dispatch_once(&s_onceToken2, ^{
            s_suffixes = @{ @(SRGVendorRSI) : @"rsi",
                            @(SRGVendorRTR) : @"rtr",
                            @(SRGVendorRTS) : @"rts",
                            @(SRGVendorSRF) : @"srf",
                            @(SRGVendorSWI) : @"swi" };
        });
        SRGVendor vendor = ApplicationConfiguration.sharedApplicationConfiguration.vendor;
        NSString *suffix = s_suffixes[@(vendor)];
        if (suffix) {
            NSString *URLString = [NSString stringWithFormat:@"https://srgplayer-%@.%@.srf.ch/play/", suffix, environment];
            [ApplicationConfiguration.sharedApplicationConfiguration setOverridePlayURL:[NSURL URLWithString:URLString]];
        }
    }
    else {
        [ApplicationConfiguration.sharedApplicationConfiguration setOverridePlayURL:nil];
    }
#endif
    SRGDataProvider.currentDataProvider = dataProvider;
}

- (void)setupAnalytics
{
    ApplicationConfiguration *applicationConfiguration = ApplicationConfiguration.sharedApplicationConfiguration;
    
    SRGAnalyticsConfiguration *configuration = [[SRGAnalyticsConfiguration alloc] initWithBusinessUnitIdentifier:applicationConfiguration.analyticsBusinessUnitIdentifier
                                                                                                       container:applicationConfiguration.analyticsContainer
                                                                                             comScoreVirtualSite:applicationConfiguration.comScoreVirtualSite
                                                                                             netMetrixIdentifier:applicationConfiguration.netMetrixIdentifier];
    [SRGAnalyticsTracker.sharedTracker startWithConfiguration:configuration
                                              identityService:SRGIdentityService.currentIdentityService];
}

// Reset the app view controller hierachy to display the specified menu item, executing the provided completion block when done.
- (void)resetWithMenuItemInfo:(MenuItemInfo *)menuItemInfo completionBlock:(void (^)(void))completionBlock
{
    void (^openMenuItemInfo)(void) = ^{
        self.sideMenuController.selectedMenuItemInfo = menuItemInfo;
        completionBlock ? completionBlock() : nil;
    };
    
    // When dismissing a view controller with a transitioning delegate while the app is in the background, with animated = NO, there
    // is a bug leading to an incorrect final state. The bug does not occur if animated = YES, but the transition is visible. To get
    // a perfect result, we completely disable animations during the transition
    if (self.sideMenuController.presentedViewController) {
        [UIView setAnimationsEnabled:NO];
        [self.sideMenuController dismissViewControllerAnimated:YES completion:^{
            [UIView setAnimationsEnabled:YES];
            openMenuItemInfo();
        }];
    }
    else {
        openMenuItemInfo();
    }
}

- (void)playURN:(NSString *)mediaURN media:(SRGMedia *)media atPosition:(SRGPosition *)position fromPushNotification:(BOOL)fromPushNotification completion:(void (^)(void))completion
{
    if (media) {
        [self.sideMenuController play_presentMediaPlayerWithMedia:media position:position fromPushNotification:fromPushNotification animated:YES completion:completion];
    }
    else {
        [[SRGDataProvider.currentDataProvider mediaWithURN:mediaURN completionBlock:^(SRGMedia * _Nullable media, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
            if (media) {
                [self.sideMenuController play_presentMediaPlayerWithMedia:media position:position fromPushNotification:fromPushNotification animated:YES completion:completion];
            }
            else {
                NSError *error = [NSError errorWithDomain:PlayErrorDomain
                                                     code:PlayErrorCodeNotFound
                                     localizedDescription:NSLocalizedString(@"The media cannot be opened.", @"Error message when a media cannot be opened via Handoff, deeplink or a push notification")];
                [Banner showError:error inViewController:nil];
            }
        }] resume];
    }
}

- (void)openShowURN:(NSString *)showURN show:(SRGShow *)show fromPushNotification:(BOOL)fromPushNotification
{
    if (show) {
        ShowViewController *showViewController = [[ShowViewController alloc] initWithShow:show fromPushNotification:fromPushNotification];
        [self.sideMenuController pushViewController:showViewController animated:YES];
    }
    else {
        [[SRGDataProvider.currentDataProvider showWithURN:showURN completionBlock:^(SRGShow * _Nullable show, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
            if (show) {
                ShowViewController *showViewController = [[ShowViewController alloc] initWithShow:show fromPushNotification:fromPushNotification];
                [self.sideMenuController pushViewController:showViewController animated:YES];
            }
            else {
                NSError *error = [NSError errorWithDomain:PlayErrorDomain
                                                     code:PlayErrorCodeNotFound
                                     localizedDescription:NSLocalizedString(@"The show cannot be opened.", @"Error message when a show cannot be opened via Handoff, deeplink or a push notification")];
                [Banner showError:error inViewController:nil];
            }
        }] resume];
    }
}

- (void)openTopicURN:(NSString *)topicURN fromPushNotification:(BOOL)fromPushNotification
{
    [[SRGDataProvider.currentDataProvider tvTopicsForVendor:ApplicationConfiguration.sharedApplicationConfiguration.vendor withCompletionBlock:^(NSArray<SRGTopic *> * _Nullable topics, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGTopic.new, URN), topicURN];
        SRGTopic *topic = [topics filteredArrayUsingPredicate:predicate].firstObject;
        if (topic) {
            HomeTopicViewController *homeTopicViewController = [[HomeTopicViewController alloc] initWithTopic:topic];
            [self.sideMenuController pushViewController:homeTopicViewController animated:YES];
        }
        else {
            NSError *error = [NSError errorWithDomain:PlayErrorDomain
                                                 code:PlayErrorCodeNotFound
                                 localizedDescription:NSLocalizedString(@"The page cannot be opened.", @"Error message when a topic cannot be opened via Handoff, deeplink or a push notification")];
            [Banner showError:error inViewController:nil];
        }
    }] resume];
}

- (void)openModuleURN:(NSString *)moduleURN fromPushNotification:(BOOL)fromPushNotification
{
    [[SRGDataProvider.currentDataProvider modulesForVendor:ApplicationConfiguration.sharedApplicationConfiguration.vendor type:SRGModuleTypeEvent withCompletionBlock:^(NSArray<SRGModule *> * _Nullable modules, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGModule.new, URN), moduleURN];
        SRGModule *module = [modules filteredArrayUsingPredicate:predicate].firstObject;
        if (module) {
             ModuleViewController *moduleViewController = [[ModuleViewController alloc] initWithModule:module];
            [self.sideMenuController pushViewController:moduleViewController animated:YES];
        }
        else {
            NSError *error = [NSError errorWithDomain:PlayErrorDomain
                                                 code:PlayErrorCodeNotFound
                                 localizedDescription:NSLocalizedString(@"The page cannot be opened.", @"Error message when an event module cannot be opened via Handoff, deeplink or a push notification")];
            [Banner showError:error inViewController:nil];
        }
    }] resume];
}

#pragma mark What's new

- (void)loadWhatsNewWithCompletionHandler:(void (^)(UIViewController * _Nullable, NSError * _Nullable))completionHandler
{
    NSURL *whatsNewURL = ApplicationConfiguration.sharedApplicationConfiguration.whatsNewURL;
    [[SRGRequest objectRequestWithURLRequest:[NSURLRequest requestWithURL:whatsNewURL] session:NSURLSession.sharedSession parser:^id _Nullable(NSData * _Nonnull data, NSError * _Nullable __autoreleasing * _Nullable pError) {
        // FIXME: Ugly. Since we are using Pastebin, the missing html extension makes the page load incorrectly. We should:
        //   1) Replace Pastebin
        //   2) Load the what's new URL in the WebViewController directly
        NSString *temporaryFileName = [NSUUID.UUID.UUIDString stringByAppendingPathExtension:@"html"];
        NSString *temporaryFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:temporaryFileName];
        NSURL *temporaryFileURL = [NSURL fileURLWithPath:temporaryFilePath];
        [data writeToURL:temporaryFileURL atomically:YES];
        
        NSString *shortVersionString = [[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] componentsSeparatedByString:@"-"].firstObject;
        NSURLComponents *components = [[NSURLComponents alloc] initWithURL:temporaryFileURL resolvingAgainstBaseURL:NO];
        components.queryItems = @[ [[NSURLQueryItem alloc] initWithName:@"build" value:[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"]],
                                   [[NSURLQueryItem alloc] initWithName:@"version" value:shortVersionString],
                                   [[NSURLQueryItem alloc] initWithName:@"ios" value:UIDevice.currentDevice.systemVersion] ];
        
        return components.URL;
    } completionBlock:^(NSURL * _Nullable URL, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            completionHandler(nil, error);
            return;
        }
        
        NSURLRequest *request = [NSURLRequest requestWithURL:URL];
        WebViewController *webViewController = [[WebViewController alloc] initWithRequest:request customizationBlock:nil decisionHandler:nil analyticsPageType:AnalyticsPageTypeSystem];
        completionHandler(webViewController, nil);
    }] resume];
}

#pragma mark Forced updates

- (void)checkForForcedUpdates
{
    NSURL *URL = [NSURL URLWithString:@"api/v1/update/check" relativeToURL:ApplicationConfiguration.sharedApplicationConfiguration.middlewareURL];
    NSURLComponents *URLComponents = [NSURLComponents componentsWithString:URL.absoluteString];
    
    NSString *bundleIdentifier = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleIdentifier"];
    NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
#if defined(DEBUG) || defined(NIGHTLY) || defined(BETA)
    version = [version componentsSeparatedByString:@"-"].firstObject;
#endif
    URLComponents.queryItems = @[ [NSURLQueryItem queryItemWithName:@"package" value:bundleIdentifier],
                                  [NSURLQueryItem queryItemWithName:@"version" value:version] ];
    
    [[SRGRequest objectRequestWithURLRequest:[NSURLRequest requestWithURL:URLComponents.URL] session:NSURLSession.sharedSession parser:^id _Nullable(NSData * _Nonnull data, NSError * _Nullable __autoreleasing * _Nullable pError) {
        NSDictionary *JSONDictionary = SRGNetworkJSONDictionaryParser(data, pError);
        if (! JSONDictionary) {
            return nil;
        }
        
        return [MTLJSONAdapter modelOfClass:UpdateInfo.class fromJSONDictionary:JSONDictionary error:pError];
    } completionBlock:^(UpdateInfo * _Nullable updateInfo, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            PlayLogWarning(@"application", @"Could not retrieve update information. Reason: %@", error);
            return;
        }
        
        switch (updateInfo.type) {
            case UpdateTypeMandatory: {
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Mandatory update", @"Message title displayed when the user is forced to update the application.")
                                                                                         message:updateInfo.reason
                                                                                  preferredStyle:UIAlertControllerStyleAlert];
                [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Update", @"Title of the button to update the application") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [self showStorePage];
                }]];
                [self.window.play_topViewController presentViewController:alertController animated:YES completion:nil];
                break;
            }
                
            case UpdateTypeOptional: {
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Recommended update", @"Message title displayed when the user is recommended to update the application.")
                                                                                         message:updateInfo.reason
                                                                                  preferredStyle:UIAlertControllerStyleAlert];
                [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Skip", @"Title of the button to skip updating the application") style:UIAlertActionStyleDefault handler:nil]];
                [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Update", @"Title of the button to update the application") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [self showStorePage];
                }]];
                [self.window.play_topViewController presentViewController:alertController animated:YES completion:nil];
                break;
            }
                
            default: {
                break;
            }
        }
    }] resume];
}

- (void)showStorePage
{
    SKStoreProductViewController *productViewController = [[SKStoreProductViewController  alloc] init];
    productViewController.delegate = self;
    
    ApplicationConfiguration *applicationConfiguration = ApplicationConfiguration.sharedApplicationConfiguration;
    [productViewController loadProductWithParameters:@{ SKStoreProductParameterITunesItemIdentifier : applicationConfiguration.appStoreProductIdentifier } completionBlock:^(BOOL result, NSError * _Nullable error) {
        if (error) {
            [self checkForForcedUpdates];
        }
    }];
    [self.window.play_topViewController presentViewController:productViewController animated:YES completion:nil];
}

#pragma mark Onboarding

- (void)showNextAvailableOnboarding
{
    static NSString * const kReadOnboardingUidsKey = @"PlaySRGReadOnboardingUids";
    
    NSArray<NSString *> *readOnboardingUids = [NSUserDefaults.standardUserDefaults stringArrayForKey:kReadOnboardingUidsKey] ?: [NSArray array];
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(Onboarding * _Nullable onboarding, NSDictionary<NSString *,id> * _Nullable bindings) {
        return ! [readOnboardingUids containsObject:onboarding.uid];
    }];
    Onboarding *onboarding = [Onboarding.onboardings filteredArrayUsingPredicate:predicate].firstObject;
    if (onboarding) {
        OnboardingViewController *onboardingViewController = [[OnboardingViewController alloc] initWithOnboarding:onboarding];
        [self.window.play_topViewController presentViewController:onboardingViewController animated:YES completion:^{
            NSArray<NSString *> *updatedReadOnboardingUids = [readOnboardingUids arrayByAddingObject:onboarding.uid];
            [NSUserDefaults.standardUserDefaults setObject:updatedReadOnboardingUids forKey:kReadOnboardingUidsKey];
            [NSUserDefaults.standardUserDefaults synchronize];
        }];
    }
}

#pragma mark BITUpdateManagerDelegate protocol

- (UIViewController *)viewControllerForHockeyManager:(BITHockeyManager *)hockeyManager componentManager:(BITHockeyBaseManager *)componentManager
{
    return self.sideMenuController;
}

#pragma mark SKStoreProductViewControllerDelegate protocol

- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController
{
    [self.window.play_topViewController dismissViewControllerAnimated:YES completion:^{
        [self checkForForcedUpdates];
    }];
}

#pragma mark Actions

- (void)closeWhatsNew:(id)sender
{
    [self.window.play_topViewController dismissViewControllerAnimated:YES completion:^{
        [self checkForForcedUpdates];
    }];
}

- (BOOL)handleShortcutItem:(UIApplicationShortcutItem *)shortcutItem
{
    MenuItemInfo *menuItemInfo = nil;
    SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
    
    if ([shortcutItem.type isEqualToString:@"favorites"]) {
        menuItemInfo = [MenuItemInfo menuItemInfoWithMenuItem:MenuItemFavorites];
        labels.type = AnalyticsTypeActionFavorites;
    }
    else if ([shortcutItem.type isEqualToString:@"downloads"]) {
        menuItemInfo = [MenuItemInfo menuItemInfoWithMenuItem:MenuItemDownloads];
        labels.type = AnalyticsTypeActionDownloads;
    }
    else if ([shortcutItem.type isEqualToString:@"history"]) {
        menuItemInfo = [MenuItemInfo menuItemInfoWithMenuItem:MenuItemHistory];
        labels.type = AnalyticsTypeActionHistory;
    }
    else if ([shortcutItem.type isEqualToString:@"search"]) {
        menuItemInfo = [MenuItemInfo menuItemInfoWithMenuItem:MenuItemSearch];
        labels.type = AnalyticsTypeActionSearch;
    }
    else {
        return NO;
    }
    
    [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleQuickActions labels:labels];
    
    [self resetWithMenuItemInfo:menuItemInfo completionBlock:nil];
    return YES;
}

#pragma mark Notifications

- (void)playbackDidContinueAutomatically:(NSNotification *)notification
{
    SRGMedia *media = notification.userInfo[SRGLetterboxMediaKey];
    if (media) {
        SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
        labels.source = AnalyticsSourceAutomatic;
        labels.type = AnalyticsTypeActionPlayMedia;
        labels.value = media.URN;
        
        SRGLetterboxController *letterboxController = notification.object;
        Playlist *playlist = [letterboxController.playlistDataSource isKindOfClass:Playlist.class] ? letterboxController.playlistDataSource : nil;
        labels.extraValue1 = playlist.recommendationUid;
        [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleContinuousPlayback labels:labels];
    }
}

- (void)userDidCancelLogin:(NSNotification *)notification
{
    SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
    labels.source = AnalyticsSourceButton;
    labels.type = AnalyticsTypeActionCancelLogin;
    [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleIdentity labels:labels];
}

- (void)userDidLogin:(NSNotification *)notification
{
    SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
    labels.source = AnalyticsSourceButton;
    labels.type = AnalyticsTypeActionLogin;
    [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleIdentity labels:labels];
}

- (void)didUpdateAccount:(NSNotification *)notification
{
    SRGAccount *account = notification.userInfo[SRGIdentityServiceAccountKey];
    if (account) {
        [NSUserDefaults.standardUserDefaults setObject:account.emailAddress forKey:PlaySRGSettingLastLoggedInEmailAddress];
        [NSUserDefaults.standardUserDefaults synchronize];
    }
}

- (void)userDidLogout:(NSNotification *)notification
{
    BOOL unexpectedLogout = [notification.userInfo[SRGIdentityServiceUnauthorizedKey] boolValue];
    if (unexpectedLogout) {
        // Display the warning banner after a while. Account view controller may take time to disappear, due to the animation.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [Banner showWithStyle:BannerStyleWarning
                          message:NSLocalizedString(@"You have been automatically logged out. Login again to keep your data synchronized across devices.", @"Notification displayed when the user has been logged out unexpectedly.")
                            image:[UIImage imageNamed:@"account-22"]
                           sticky:YES
                 inViewController:nil];
        });
    }
    
    SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
    labels.source = unexpectedLogout ? AnalyticsSourceAutomatic : AnalyticsSourceButton;
    labels.type = AnalyticsTypeActionLogout;
    [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleIdentity labels:labels];
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (s_kvoContext == context) {
        if ([keyPath isEqualToString:PlaySRGSettingServiceURL] || [keyPath isEqualToString:PlaySRGSettingUserLocation]) {
            id oldValue = change[NSKeyValueChangeOldKey];
            id newValue = change[NSKeyValueChangeNewKey];
            
            if (! [newValue isEqual:oldValue]) {
                [[NSURLCache sharedURLCache] removeAllCachedResponses];
                
                [self setupDataProvider];
                
                // Stop the current player
                // TODO: For perfectly safe behavior when the service URL is changed, we should have all Letterbox
                //       controllers observe URL settings change and do the following in such cases. This is probably
                //       overkill for the time being.
                
                SRGLetterboxController *serviceController = SRGLetterboxService.sharedService.controller;
                [serviceController reset];
                ApplicationConfigurationApplyControllerSettings(serviceController);
            }
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end

#pragma mark Static functions

static MenuItemInfo *MenuItemInfoForChannelUid(NSString *channelUid)
{
    if (channelUid) {
        RadioChannel *radioChannel = [ApplicationConfiguration.sharedApplicationConfiguration radioChannelForUid:channelUid];
        if (radioChannel) {
            return [MenuItemInfo menuItemInfoWithRadioChannel:radioChannel];
        }
    }
    return [MenuItemInfo menuItemInfoWithMenuItem:MenuItemTVOverview];
}
