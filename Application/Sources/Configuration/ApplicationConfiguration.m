//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "ApplicationConfiguration.h"

#import "ApplicationSettings.h"
#import "PlayLogger.h"
#import "UIColor+PlaySRG.h"
#import "SRGMedia+PlaySRG.h"

#import <Firebase/Firebase.h>
#import <GoogleCast/GoogleCast.h>
#import <libextobjc/libextobjc.h>
#import <SRGAppearance/SRGAppearance.h>
#import <SRGLetterbox/SRGLetterbox.h>

NSString * const ApplicationConfigurationDidChangeNotification = @"ApplicationConfigurationDidChangeNotification";

NSString *TitleForHomeSection(HomeSection homeSection)
{
    static NSDictionary<NSNumber *, NSString *> *s_names;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        s_names = @{ @(HomeSectionTVTrending) : NSLocalizedString(@"Trending videos", @"Title label used to present trending TV videos"),
                     @(HomeSectionTVLive) : NSLocalizedString(@"TV", @"Title label to present main TV livestreams"),
                     @(HomeSectionTVEvents) : NSLocalizedString(@"Events", @"Title label used to present TV events while loading. It appears if no network connection available and no cache available."),
                     @(HomeSectionTVTopics) : NSLocalizedString(@"Topics", @"Title label used to present TV topics while loading. It appears if no network connection available and no cache available."),
                     @(HomeSectionTVLatest) : NSLocalizedString(@"Latest videos", @"Title label used to present the latest videos"),
                     @(HomeSectionTVMostPopular) : NSLocalizedString(@"Most popular", @"Title label used to present the TV most seen / clicked / popular videos"),
                     @(HomeSectionTVSoonExpiring) : NSLocalizedString(@"Available for a limited time", @"Title label used to present the soon expiring videos"),
                     @(HomeSectionTVScheduledLivestreams) : NSLocalizedString(@"Events", @"Title label used to present scheduled livestream medias. Only on test versions."),
                     @(HomeSectionTVLiveCenter) : NSLocalizedString(@"Sport", @"Title label used to present live center medias. Only on test versions."),
                     @(HomeSectionTVShowsAccess) : NSLocalizedString(@"Shows", @"Title label used to present the TV shows AZ and TV shows by date access buttons."),
                     @(HomeSectionTVFavoriteShows) : NSLocalizedString(@"Favorites", @"Title label used to present the TV favorite shows."),
                     @(HomeSectionRadioLive) : NSLocalizedString(@"Radio", @"Title label to present main radio livestreams"),
                     @(HomeSectionRadioLatestEpisodes) : NSLocalizedString(@"The latest episodes", @"Title label used to present the radio latest audio episodes"),
                     @(HomeSectionRadioMostPopular) : NSLocalizedString(@"Most listened to", @"Title label used to present the radio most listened / popular audio medias"),
                     @(HomeSectionRadioLatest) : NSLocalizedString(@"The latest audios", @"Title label used to present the radio latest audios"),
                     @(HomeSectionRadioLatestVideos) : NSLocalizedString(@"Latest videos", @"Title label used to present the radio latest videos"),
                     @(HomeSectionRadioAllShows) : NSLocalizedString(@"Shows", @"Title label used to present radio associated shows"),
                     @(HomeSectionRadioShowsAccess) : NSLocalizedString(@"Shows", @"Title label used to present the radio shows AZ and radio shows by date access buttons."),
                     @(HomeSectionRadioFavoriteShows) : NSLocalizedString(@"Favorites", @"Title label used to present the radio favorite shows.") };
    });
    return s_names[@(homeSection)];
}

NSString *TitleForTopicSection(TopicSection topicSection)
{
    static NSDictionary<NSNumber *, NSString *> *s_names;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        s_names = @{ @(TopicSectionLatest) : NSLocalizedString(@"Most recent", @"Short title for the most recent video topic list"),
                     @(TopicSectionMostPopular) : NSLocalizedString(@"Most popular", @"Short title for the most clicked video topic list") };
    });
    return s_names[@(topicSection)];
}

static NSString *AnalyticsBusinessUnitIdentifier(NSString *businessUnitIdentifier)
{
    static NSDictionary<NSString *, SRGAnalyticsBusinessUnitIdentifier>  *s_businessUnitIdentifiers;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        s_businessUnitIdentifiers = @{ @"rsi" : SRGAnalyticsBusinessUnitIdentifierRSI,
                                       @"rtr" : SRGAnalyticsBusinessUnitIdentifierRTR,
                                       @"rts" : SRGAnalyticsBusinessUnitIdentifierRTS,
                                       @"srf" : SRGAnalyticsBusinessUnitIdentifierSRF,
                                       @"swi" : SRGAnalyticsBusinessUnitIdentifierSWI };
    });
    return s_businessUnitIdentifiers[businessUnitIdentifier];
}

static SRGVendor DataProviderVendor(NSString *businessUnitIdentifier)
{
    static NSDictionary<NSString *, NSNumber *> *s_vendors;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        s_vendors = @{ @"rsi" : @(SRGVendorRSI),
                       @"rtr" : @(SRGVendorRTR),
                       @"rts" : @(SRGVendorRTS),
                       @"srf" : @(SRGVendorSRF),
                       @"swi" : @(SRGVendorSWI) };
    });
    return s_vendors[businessUnitIdentifier].integerValue;
}

static HomeSection HomeSectionWithString(NSString *string)
{
    static dispatch_once_t s_onceToken;
    static NSDictionary<NSString *, NSNumber *> *s_sections;
    dispatch_once(&s_onceToken, ^{
        s_sections = @{ @"tvTrending" : @(HomeSectionTVTrending),
                        @"tvLive" : @(HomeSectionTVLive),
                        @"tvEvents" : @(HomeSectionTVEvents),
                        @"tvTopics" : @(HomeSectionTVTopics),
                        @"tvLatest" : @(HomeSectionTVLatest),
                        @"tvMostPopular" : @(HomeSectionTVMostPopular),
                        @"tvSoonExpiring" : @(HomeSectionTVSoonExpiring),
                        @"tvScheduledLivestreams" : @(HomeSectionTVScheduledLivestreams),
                        @"tvLiveCenter" : @(HomeSectionTVLiveCenter),
                        @"tvShowsAccess" : @(HomeSectionTVShowsAccess),
                        @"tvFavoriteShows" : @(HomeSectionTVFavoriteShows),
                        @"radioLive" : @(HomeSectionRadioLive),
                        @"radioLatestEpisodes" : @(HomeSectionRadioLatestEpisodes),
                        @"radioMostPopular" : @(HomeSectionRadioMostPopular),
                        @"radioLatest" : @(HomeSectionRadioLatest),
                        @"radioLatestVideos" : @(HomeSectionRadioLatestVideos),
                        @"radioAllShows" : @(HomeSectionRadioAllShows),
                        @"radioShowsAccess" : @(HomeSectionRadioShowsAccess),
                        @"radioFavoriteShows" : @(HomeSectionRadioFavoriteShows) };
    });
    NSNumber *section = s_sections[string];
    return section ? section.integerValue : HomeSectionUnknown;
}

static TopicSection TopicSectionWithString(NSString *string)
{
    static dispatch_once_t s_onceToken;
    static NSDictionary<NSString *, NSNumber *> *s_sections;
    dispatch_once(&s_onceToken, ^{
        s_sections = @{ @"latest" : @(TopicSectionLatest),
                        @"mostPopular" : @(TopicSectionMostPopular) };
    });
    NSNumber *section = s_sections[string];
    return section ? section.integerValue : TopicSectionUnknown;
}

HomeSection HomeSectionForApplicationSection(ApplicationSection applicationSection)
{
    static dispatch_once_t s_onceToken;
    static NSDictionary<NSNumber *, NSNumber *> *s_sections;
    dispatch_once(&s_onceToken, ^{
        s_sections = @{ @(ApplicationSectionTVLive) : @(HomeSectionTVLive),
                        @(ApplicationSectionRadioLive) : @(HomeSectionRadioLive),
                        @(ApplicationSectionLiveCenter) : @(HomeSectionTVLiveCenter),
                        @(ApplicationSectionScheduledLivestreams) : @(HomeSectionTVScheduledLivestreams) };
    });
    NSNumber *section = s_sections[@(applicationSection)];
    return section ? section.integerValue : HomeSectionUnknown;
}

NSString *TitleForApplicationSection(ApplicationSection applicationSection)
{
    static NSDictionary<NSNumber *, NSString *> *s_names;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        s_names = @{ @(ApplicationSectionDownloads) : NSLocalizedString(@"Downloads", @"Label to present downloads"),
                     @(ApplicationSectionFavorites) : NSLocalizedString(@"Favorites", @"Label to present Favorites"),
                     @(ApplicationSectionFeedback) : NSLocalizedString(@"Feedback", @"Label to display the feedback form"),
                     @(ApplicationSectionHistory) : NSLocalizedString(@"History", @"Label to present history"),
                     @(ApplicationSectionHelp) : NSLocalizedString(@"Help and copyright", @"Label to present the help page"),
                     @(ApplicationSectionNotifications) : NSLocalizedString(@"Notifications", @"Label to present the help page"),
                     @(ApplicationSectionSearch) : NSLocalizedString(@"Search", @"Label to present the search view"),
                     @(ApplicationSectionShowByDate) : NSLocalizedString(@"Programmes by date", @"Label to present programmes by date"),
                     @(ApplicationSectionOverview) : NSLocalizedString(@"Overview", @"Label to present the main Videos / Audios views"),
                     @(ApplicationSectionShowAZ) : NSLocalizedString(@"Programmes A-Z", @"Label to present shows A to Z (radio or TV)"),
                     @(ApplicationSectionWatchLater) : NSLocalizedString(@"Watch later", @"Label to present the watch later list") };
    });
    return s_names[@(applicationSection)];
}

void ApplicationConfigurationApplyControllerSettings(SRGLetterboxController *controller)
{
    controller.serviceURL = SRGDataProvider.currentDataProvider.serviceURL;
    controller.globalParameters = SRGDataProvider.currentDataProvider.globalParameters;
    controller.backgroundVideoPlaybackEnabled = ApplicationSettingBackgroundVideoPlaybackEnabled();
    
    ApplicationConfiguration *applicationConfiguration = ApplicationConfiguration.sharedApplicationConfiguration;
    controller.endTolerance = applicationConfiguration.endTolerance;
    controller.endToleranceRatio = applicationConfiguration.endToleranceRatio;
}

NSTimeInterval ApplicationConfigurationEffectiveEndTolerance(NSTimeInterval duration)
{
    ApplicationConfiguration *applicationConfiguration = ApplicationConfiguration.sharedApplicationConfiguration;
    CMTime tolerance = SRGMediaPlayerEffectiveEndTolerance(applicationConfiguration.endTolerance, applicationConfiguration.endToleranceRatio, duration);
    return CMTimeGetSeconds(tolerance);
}

@interface ApplicationConfiguration ()

@property (nonatomic) FIRRemoteConfig *remoteConfig;

@property (nonatomic) SRGVendor vendor;

@property (nonatomic, copy) SRGAnalyticsBusinessUnitIdentifier analyticsBusinessUnitIdentifier;
@property (nonatomic) NSInteger analyticsContainer;

@property (nonatomic, copy) NSString *comScoreVirtualSite;
@property (nonatomic, copy) NSString *netMetrixIdentifier;

@property (nonatomic, copy) NSString *voiceOverLanguageCode;

@property (nonatomic, copy) NSString *googleCastReceiverIdentifier;
@property (nonatomic, copy) NSNumber *appStoreProductIdentifier;

@property (nonatomic) NSURL *playURL;
@property (nonatomic) NSURL *middlewareURL;
@property (nonatomic) NSURL *identityWebserviceURL;
@property (nonatomic) NSURL *identityWebsiteURL;
@property (nonatomic) NSURL *userDataServiceURL;

@property (nonatomic) NSURL *whatsNewURL;
@property (nonatomic) NSURL *feedbackURL;
@property (nonatomic) NSURL *impressumURL;
@property (nonatomic) NSURL *termsAndConditionsURL;
@property (nonatomic) NSURL *dataProtectionURL;
@property (nonatomic) NSURL *betaTestingURL;
@property (nonatomic) NSURL *sourceCodeURL;

@property (nonatomic, getter=areDownloadsHintsHidden) BOOL downloadsHintsHidden;
@property (nonatomic, getter=areMoreEpisodesHidden) BOOL moreEpisodesHidden;
@property (nonatomic, getter=areModuleColorsDisabled) BOOL moduleColorsDisabled;

@property (nonatomic, getter=isSubtitleAvailabilityHidden) BOOL subtitleAvailabilityHidden;
@property (nonatomic, getter=isAudioDescriptionAvailabilityHidden) BOOL audioDescriptionAvailabilityHidden;

@property (nonatomic) UIColor *moduleDefaultLinkColor;
@property (nonatomic) UIColor *moduleDefaultTextColor;

@property (nonatomic) NSArray<NSNumber *> *searchOptions;

@property (nonatomic) NSArray<NSNumber *> *videoHomeSections;
@property (nonatomic) NSArray<NSNumber *> *liveHomeSections;

@property (nonatomic) BOOL tvTrendingEpisodesOnly;
@property (nonatomic) NSNumber *tvTrendingEditorialLimit;

@property (nonatomic, getter=isTvFeaturedHomeSectionHeaderHidden) BOOL tvFeaturedHomeSectionHeaderHidden;

@property (nonatomic) NSInteger tvNumberOfLivePlaceholders;

@property (nonatomic) NSInteger minimumSocialViewCount;

@property (nonatomic) NSArray<NSNumber *> *topicSections;
@property (nonatomic) NSArray<NSNumber *> *topicSectionsWithSubtopics;

@property (nonatomic) NSArray<RadioChannel *> *radioChannels;
@property (nonatomic) NSArray<NSNumber *> *audioHomeSections;                           // wrap `HomeSection` values

@property (nonatomic) NSArray<TVChannel *> *tvChannels;

@property (nonatomic, getter=isRadioFeaturedHomeSectionHeaderHidden) BOOL radioFeaturedHomeSectionHeaderHidden;

@property (nonatomic) NSUInteger pageSize;

@property (nonatomic) NSTimeInterval continuousPlaybackPlayerViewTransitionDuration;
@property (nonatomic) NSTimeInterval continuousPlaybackForegroundTransitionDuration;
@property (nonatomic) NSTimeInterval continuousPlaybackBackgroundTransitionDuration;

@property (nonatomic) NSTimeInterval endTolerance;
@property (nonatomic) float endToleranceRatio;

@property (nonatomic) NSArray<NSString *> *hiddenOnboardingUids;

@property (nonatomic, getter=isLogoutMenuEnabled) BOOL logoutMenuEnabled;

@property (nonatomic, getter=areSearchSettingsHidden) BOOL searchSettingsHidden;
@property (nonatomic, getter=isSearchSettingSubtitledHidden) BOOL searchSettingSubtitledHidden;
@property (nonatomic, getter=isShowsSearchHidden) BOOL showsSearchHidden;

@property (nonatomic) NSDictionary<NSString *, NSDictionary *> *topicHeaders;

#if defined(DEBUG) || defined(NIGHTLY) || defined(BETA)
@property (nonatomic) NSURL *overridePlayURL;
#endif

@end

@implementation ApplicationConfiguration

#pragma mark Class methods

+ (ApplicationConfiguration *)sharedApplicationConfiguration
{
    static dispatch_once_t s_onceToken;
    static ApplicationConfiguration *s_applicationConfiguration;
    dispatch_once(&s_onceToken, ^{
        s_applicationConfiguration = [[ApplicationConfiguration alloc] init];
    });
    return s_applicationConfiguration;
}

#pragma mark Object lifecycle

- (instancetype)init
{
    if (self = [super init]) {
        self.remoteConfig = [FIRRemoteConfig remoteConfig];
#if defined(DEBUG) || defined(NIGHTLY)
        // Make it possible to retrieve the configuration more frequently during development
        // See https://firebase.google.com/support/faq/#remote-config-values
        self.remoteConfig.configSettings = [[FIRRemoteConfigSettings alloc] initWithDeveloperModeEnabled:YES];
#endif
        
        // Read the embedded configuration JSON
        NSString *configurationFile = [NSBundle.mainBundle pathForResource:@"ApplicationConfiguration" ofType:@"json"];
        NSData *configurationFileData = [NSData dataWithContentsOfFile:configurationFile];
        id configurationJSONObject = [NSJSONSerialization JSONObjectWithData:configurationFileData options:0 error:NULL];
        NSAssert([configurationJSONObject isKindOfClass:NSDictionary.class], @"A valid default configuration dictionary is required");
        
        // Use this JSON as default remote configuration
        [self.remoteConfig setDefaults:configurationJSONObject];
        
        __unused BOOL isDefaultRemoteConfigValid = [self synchronizeRemoteConfiguration];
        NSAssert(isDefaultRemoteConfigValid, @"The default remote configuration must be valid");
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(applicationDidBecomeActive:)
                                                   name:UIApplicationDidBecomeActiveNotification
                                                 object:nil];
        
        [self update];
    }
    return self;
}

#pragma mark Getters and setters

- (BOOL)isContinuousPlaybackAvailable
{
    return self.continuousPlaybackBackgroundTransitionDuration != SRGLetterboxContinuousPlaybackDisabled
        || self.continuousPlaybackForegroundTransitionDuration != SRGLetterboxContinuousPlaybackDisabled
        || self.continuousPlaybackPlayerViewTransitionDuration != SRGLetterboxContinuousPlaybackDisabled;
}

#pragma mark Remote configuration

- (void)update
{
    // Cached configuration expiration must be large enough, except in development builds, see
    //   https://firebase.google.com/support/faq/#remote-config-values
#if defined(DEBUG) || defined(NIGHTLY)
    static const NSTimeInterval kExpirationDuration = 30.;
#else
    static const NSTimeInterval kExpirationDuration = 15. * 60.;
#endif
    
    [self.remoteConfig fetchWithExpirationDuration:kExpirationDuration completionHandler:^(FIRRemoteConfigFetchStatus status, NSError * _Nullable error) {
        [self.remoteConfig activateFetched];
        
        if (! [self synchronizeRemoteConfiguration]) {
            PlayLogWarning(@"configuration", @"The newly fetched remote application configuration is invalid and was not applied");
        }
    }];
}

// Return YES iff the activated remote configuration is valid, and stores the corresponding values. If the configuration
// is not valid, the method returns NO and does not synchronize anything (i.e. the values will not be reflected by
// the ApplicationConfiguration instance)
- (BOOL)synchronizeRemoteConfiguration
{
    //
    // Mandatory values. Do not update the local configuration if one is missing
    //
    
    NSString *businessUnitIdentifier = [self.remoteConfig configValueForKey:@"businessUnit"].stringValue;
    if (businessUnitIdentifier.length == 0) {
        return NO;
    }
    
    SRGVendor vendor = DataProviderVendor(businessUnitIdentifier);
    if (vendor == SRGVendorNone) {
        return NO;
    }
    
    NSString *analyticsBusinessUnitIdentifier = AnalyticsBusinessUnitIdentifier(businessUnitIdentifier);
    if (analyticsBusinessUnitIdentifier.length == 0) {
        return NO;
    }
    
    FIRRemoteConfigValue *analyticsContainer = [self.remoteConfig configValueForKey:@"container"];
    if (analyticsContainer.source == FIRRemoteConfigSourceStatic) {
        return NO;
    }
    
    NSString *comScoreVirtualSite = [self.remoteConfig configValueForKey:@"comScoreVirtualSite"].stringValue;
    if (comScoreVirtualSite.length == 0) {
        return NO;
    }
    
    NSString *netMetrixIdentifier = [self.remoteConfig configValueForKey:@"netMetrixIdentifier"].stringValue;
    if (netMetrixIdentifier.length == 0) {
        return NO;
    }
    
    NSString *playURLString = [self.remoteConfig configValueForKey:@"playURL"].stringValue;
    NSURL *playURL = (playURLString.length != 0) ? [NSURL URLWithString:playURLString] : nil;
    if (! playURL) {
        return NO;
    }
    
    NSString *middlewareURLString = [self.remoteConfig configValueForKey:@"middlewareURL"].stringValue;
    NSURL *middlewareURL = (middlewareURLString.length != 0) ? [NSURL URLWithString:middlewareURLString] : nil;
    if (! middlewareURL) {
        return NO;
    }
    
    NSString *whatsNewURLString = [self.remoteConfig configValueForKey:@"whatsNewURL"].stringValue;
    NSURL *whatsNewURL = (whatsNewURLString.length != 0) ? [NSURL URLWithString:whatsNewURLString] : nil;
    if (! whatsNewURL) {
        return NO;
    }
    
    NSNumber *appStoreProductIdentifier = [self.remoteConfig configValueForKey:@"appStoreProductIdentifier"].numberValue;
    if (appStoreProductIdentifier.integerValue == 0) {
        return NO;
    }
    
    NSString *moduleDefaultLinkColorString = [self.remoteConfig configValueForKey:@"moduleDefaultLinkColor"].stringValue;
    UIColor *moduleDefaultLinkColor = (moduleDefaultLinkColorString.length != 0) ? [UIColor srg_colorFromHexadecimalString:moduleDefaultLinkColorString] : nil;
    if (! moduleDefaultLinkColor) {
        return NO;
    }
    
    NSString *moduleDefaultTextColorString = [self.remoteConfig configValueForKey:@"moduleDefaultTextColor"].stringValue;
    UIColor *moduleDefaultTextColor = (moduleDefaultTextColorString.length != 0) ? [UIColor srg_colorFromHexadecimalString:moduleDefaultTextColorString] : nil;
    if (! moduleDefaultTextColor) {
        return NO;
    }
    
    // Update mandatory values
    self.analyticsBusinessUnitIdentifier = analyticsBusinessUnitIdentifier;
    self.analyticsContainer = analyticsContainer.numberValue.integerValue;
    self.vendor = vendor;
    self.comScoreVirtualSite = comScoreVirtualSite;
    self.netMetrixIdentifier = netMetrixIdentifier;
    
    self.playURL = playURL;
    self.middlewareURL = middlewareURL;
    self.whatsNewURL = whatsNewURL;
    
    self.appStoreProductIdentifier = appStoreProductIdentifier;
    
    self.moduleDefaultLinkColor = moduleDefaultLinkColor;
    self.moduleDefaultTextColor = moduleDefaultTextColor;
    
    //
    // Optional values
    //
    
    NSString *voiceOverLanguageCode = [self.remoteConfig configValueForKey:@"voiceOverLanguageCode"].stringValue;
    self.voiceOverLanguageCode = (voiceOverLanguageCode.length != 0) ? voiceOverLanguageCode : nil;
    
    NSString *googleCastReceiverIdentifier = [self.remoteConfig configValueForKey:@"googleCastReceiverIdentifier"].stringValue;
    self.googleCastReceiverIdentifier = (googleCastReceiverIdentifier.length != 0) ? googleCastReceiverIdentifier : kGCKDefaultMediaReceiverApplicationID;
    
    NSString *identityWebserviceURLString = [self.remoteConfig configValueForKey:@"identityWebserviceURL"].stringValue;
    self.identityWebserviceURL = (identityWebserviceURLString.length != 0) ? [NSURL URLWithString:identityWebserviceURLString] : nil;
    
    NSString *identityWebsiteURLString = [self.remoteConfig configValueForKey:@"identityWebsiteURL"].stringValue;
    self.identityWebsiteURL = (identityWebsiteURLString.length != 0) ? [NSURL URLWithString:identityWebsiteURLString] : nil;
    
    NSString *userDataServiceURLString = [self.remoteConfig configValueForKey:@"userDataServiceURL"].stringValue;
    self.userDataServiceURL = (userDataServiceURLString.length != 0) ? [NSURL URLWithString:userDataServiceURLString] : nil;
    
    NSString *feedbackURLString = [self.remoteConfig configValueForKey:@"feedbackURL"].stringValue;
    self.feedbackURL = (feedbackURLString.length != 0) ? [NSURL URLWithString:feedbackURLString] : nil;
    
    NSString *impressumURLString = [self.remoteConfig configValueForKey:@"impressumURL"].stringValue;
    self.impressumURL = (impressumURLString.length != 0) ? [NSURL URLWithString:impressumURLString] : nil;
    
    NSString *betaTestingURLString = [self.remoteConfig configValueForKey:@"betaTestingURL"].stringValue;
    self.betaTestingURL = (betaTestingURLString.length != 0) ? [NSURL URLWithString:betaTestingURLString] : nil;
    
    NSString *sourceCodeURLString = [self.remoteConfig configValueForKey:@"sourceCodeURL"].stringValue;
    self.sourceCodeURL = (sourceCodeURLString.length != 0) ? [NSURL URLWithString:sourceCodeURLString] : nil;
    
    NSString *termsAndConditionsURLString = [self.remoteConfig configValueForKey:@"termsAndConditionsURL"].stringValue;
    self.termsAndConditionsURL = (termsAndConditionsURLString.length != 0) ? [NSURL URLWithString:termsAndConditionsURLString] : nil;
    
    NSString *dataProtectionURLString = [self.remoteConfig configValueForKey:@"dataProtectionURL"].stringValue;
    self.dataProtectionURL = (dataProtectionURLString.length != 0) ? [NSURL URLWithString:dataProtectionURLString] : nil;
    
    FIRRemoteConfigValue *tvNumberOfLivePlaceholders = [self.remoteConfig configValueForKey:@"tvNumberOfLivePlaceholders"];
    self.tvNumberOfLivePlaceholders = (tvNumberOfLivePlaceholders.source != FIRRemoteConfigSourceStatic) ? MAX(tvNumberOfLivePlaceholders.numberValue.integerValue, 0) : 3;
    
    FIRRemoteConfigValue *minimumSocialViewCount = [self.remoteConfig configValueForKey:@"minimumSocialViewCount"];
    self.minimumSocialViewCount = (minimumSocialViewCount.stringValue.length > 0) ? MAX(minimumSocialViewCount.numberValue.integerValue, 0) : NSIntegerMax;
    
    self.downloadsHintsHidden = [self.remoteConfig configValueForKey:@"downloadsHintsHidden"].boolValue;
    self.moreEpisodesHidden = [self.remoteConfig configValueForKey:@"moreEpisodesHidden"].boolValue;
    self.moduleColorsDisabled = [self.remoteConfig configValueForKey:@"moduleColorsDisabled"].boolValue;
    
    self.subtitleAvailabilityHidden = [self.remoteConfig configValueForKey:@"subtitleAvailabilityHidden"].boolValue;
    self.audioDescriptionAvailabilityHidden = [self.remoteConfig configValueForKey:@"audioDescriptionAvailabilityHidden"].boolValue;
    
    NSString *videoHomeSectionsString = [self.remoteConfig configValueForKey:@"videoHomeSections"].stringValue;
    self.videoHomeSections = [self homeSectionsFromString:videoHomeSectionsString];
    
    NSString *liveHomeSectionsString = [self.remoteConfig configValueForKey:@"liveHomeSections"].stringValue;
    self.liveHomeSections = [self homeSectionsFromString:liveHomeSectionsString];
    
    self.tvTrendingEpisodesOnly = [self.remoteConfig configValueForKey:@"tvTrendingEpisodesOnly"].boolValue;
    
    FIRRemoteConfigValue *tvTrendingEditorialLimit = [self.remoteConfig configValueForKey:@"tvTrendingEditorialLimit"];
    self.tvTrendingEditorialLimit = (tvTrendingEditorialLimit.source != FIRRemoteConfigSourceStatic) ? @(MAX(tvTrendingEditorialLimit.numberValue.integerValue, 0)) : nil;
    
    self.tvFeaturedHomeSectionHeaderHidden = [self.remoteConfig configValueForKey:@"tvFeaturedHomeSectionHeaderHidden"].boolValue;
    
    NSMutableArray<NSNumber *> *topicSections = [NSMutableArray array];
    NSString *topicSectionsString = [self.remoteConfig configValueForKey:@"topicSections"].stringValue;
    if (topicSectionsString.length != 0) {
        NSArray<NSString *> *topicSectionIdentifiers = [topicSectionsString componentsSeparatedByString:@","];
        for (NSString *identifier in topicSectionIdentifiers) {
            TopicSection topicSection = TopicSectionWithString(identifier);
            if (topicSection != TopicSectionUnknown) {
                [topicSections addObject:@(topicSection)];
            }
            else {
                PlayLogWarning(@"configuration", @"Unknown topic section identifier %@. Skipped.", identifier);
            }
        }
    }
    self.topicSections = topicSections.copy;
    
    NSMutableArray<NSNumber *> *topicSectionsWithSubtopics = [NSMutableArray array];
    NSString *topicSectionsWithSubtopicsString = [self.remoteConfig configValueForKey:@"topicSectionsWithSubtopics"].stringValue;
    if (topicSectionsWithSubtopicsString.length != 0) {
        NSArray<NSString *> *topicSectionIdentifiers = [topicSectionsWithSubtopicsString componentsSeparatedByString:@","];
        for (NSString *identifier in topicSectionIdentifiers) {
            TopicSection topicSection = TopicSectionWithString(identifier);
            if (topicSection != TopicSectionUnknown) {
                [topicSectionsWithSubtopics addObject:@(topicSection)];
            }
            else {
                PlayLogWarning(@"configuration", @"Unknown topic section with subtopics identifier %@. Skipped.", identifier);
            }
        }
    }
    self.topicSectionsWithSubtopics = topicSectionsWithSubtopics.copy;
    
    NSString *audioHomeSectionsString = [self.remoteConfig configValueForKey:@"audioHomeSections"].stringValue;
    self.audioHomeSections = [self homeSectionsFromString:audioHomeSectionsString];
    
    self.radioFeaturedHomeSectionHeaderHidden = [self.remoteConfig configValueForKey:@"radioFeaturedHomeSectionHeaderHidden"].boolValue;
    
    NSMutableArray<RadioChannel *> *radioChannels = [NSMutableArray array];
    if ([self.remoteConfig configValueForKey:@"radioChannels"].stringValue.length) {
        NSData *radioChannelsJSONData = [self.remoteConfig configValueForKey:@"radioChannels"].dataValue;
        id radioChannelsJSONObject = [NSJSONSerialization JSONObjectWithData:radioChannelsJSONData options:0 error:NULL];
        if ([radioChannelsJSONObject isKindOfClass:NSArray.class]) {
            for (id radioChannelDictionary in radioChannelsJSONObject) {
                if ([radioChannelDictionary isKindOfClass:NSDictionary.class]) {
                    // Transform homeSections string to a homeSection array, or use the default one
                    NSArray<NSNumber *> *homeSections = self.audioHomeSections;
                    
                    id audioHomeSectionsValue = radioChannelDictionary[@"homeSections"];
                    if ([audioHomeSectionsValue isKindOfClass:NSString.class]) {
                        NSArray<NSNumber *> *homeSectionsOverrides = [self homeSectionsFromString:audioHomeSectionsValue];
                        if (homeSectionsOverrides.count != 0) {
                            homeSections = homeSectionsOverrides;
                        }
                    }
                    
                    NSMutableDictionary *mutableRadioChannelDictionary = [radioChannelDictionary mutableCopy];
                    mutableRadioChannelDictionary[@"homeSections"] = homeSections;
                    RadioChannel *radioChannel = [[RadioChannel alloc] initWithDictionary:mutableRadioChannelDictionary.copy];
                    if (radioChannel) {
                        [radioChannels addObject:radioChannel];
                    }
                    else {
                        PlayLogWarning(@"configuration", @"Radio channel configuration is not valid. The dictionary of %@ is not valid.", radioChannelDictionary[@"uid"]);
                    }
                }
                else {
                    PlayLogWarning(@"configuration", @"Radio channel configuration is not valid. A dictionary is required.");
                }
            }
        }
        else {
            PlayLogWarning(@"configuration", @"Radio channel configuration is not valid. A JSON array is required.");
        }
    }
    self.radioChannels = radioChannels.copy;
    
    NSMutableArray<TVChannel *> *tvChannels = [NSMutableArray array];
    if ([self.remoteConfig configValueForKey:@"tvChannels"].stringValue.length) {
        NSData *tvChannelsJSONData = [self.remoteConfig configValueForKey:@"tvChannels"].dataValue;
        id tvChannelsJSONObject = [NSJSONSerialization JSONObjectWithData:tvChannelsJSONData options:0 error:NULL];
        if ([tvChannelsJSONObject isKindOfClass:NSArray.class]) {
            for (id tvChannelDictionary in tvChannelsJSONObject) {
                if ([tvChannelDictionary isKindOfClass:NSDictionary.class]) {
                    TVChannel *tvChannel = [[TVChannel alloc] initWithDictionary:tvChannelDictionary];
                    if (tvChannel) {
                        [tvChannels addObject:tvChannel];
                    }
                    else {
                        PlayLogWarning(@"configuration", @"TV channel configuration is not valid. The dictionary of %@ is not valid.", tvChannelDictionary[@"uid"]);
                    }
                }
                else {
                    PlayLogWarning(@"configuration", @"TV channel configuration is not valid. A dictionary is required.");
                }
            }
        }
        else {
            PlayLogWarning(@"configuration", @"TV channel configuration is not valid. A JSON array is required.");
        }
    }
    self.tvChannels = tvChannels.copy;
    
    FIRRemoteConfigValue *pageSize = [self.remoteConfig configValueForKey:@"pageSize"];
    self.pageSize = (pageSize.source != FIRRemoteConfigSourceStatic) ? MAX(pageSize.numberValue.unsignedIntegerValue, 1) : 20;
    
    NSMutableDictionary<NSString *, NSDictionary *> *topicHeaders = [NSMutableDictionary dictionary];
    if ([self.remoteConfig configValueForKey:@"topicHeaders"].stringValue.length) {
        NSData *topicHeadersJSONData = [self.remoteConfig configValueForKey:@"topicHeaders"].dataValue;
        id topicHeadersJSONObject = [NSJSONSerialization JSONObjectWithData:topicHeadersJSONData options:0 error:NULL];
        if ([topicHeadersJSONObject isKindOfClass:NSArray.class]) {
            for (id topicHeaderDictionary in topicHeadersJSONObject) {
                if ([topicHeaderDictionary isKindOfClass:NSDictionary.class] && topicHeaderDictionary[@"uid"] && topicHeaderDictionary[@"imageURL"]) {
                    topicHeaders[topicHeaderDictionary[@"uid"]] = topicHeaderDictionary;
                }
                else {
                    PlayLogWarning(@"configuration", @"Topic header configuration is not valid. A dictionary is required.");
                }
            }
        }
        else {
            PlayLogWarning(@"configuration", @"Topic header configuration is not valid. A JSON array is required.");
        }
    }
    self.topicHeaders = topicHeaders.copy;
    
    FIRRemoteConfigValue *continuousPlaybackPlayerViewTransitionDuration = [self.remoteConfig configValueForKey:@"continuousPlaybackPlayerViewTransitionDuration"];
    self.continuousPlaybackPlayerViewTransitionDuration = (continuousPlaybackPlayerViewTransitionDuration.stringValue.length > 0) ? fmax(continuousPlaybackPlayerViewTransitionDuration.numberValue.doubleValue, 0.) : SRGLetterboxContinuousPlaybackDisabled;
    
    FIRRemoteConfigValue *continuousPlaybackForegroundTransitionDuration = [self.remoteConfig configValueForKey:@"continuousPlaybackForegroundTransitionDuration"];
    self.continuousPlaybackForegroundTransitionDuration = (continuousPlaybackForegroundTransitionDuration.stringValue.length > 0) ? fmax(continuousPlaybackForegroundTransitionDuration.numberValue.doubleValue, 0.) : SRGLetterboxContinuousPlaybackDisabled;
    
    FIRRemoteConfigValue *continuousPlaybackBackgroundTransitionDuration = [self.remoteConfig configValueForKey:@"continuousPlaybackBackgroundTransitionDuration"];
    self.continuousPlaybackBackgroundTransitionDuration = (continuousPlaybackBackgroundTransitionDuration.stringValue.length > 0) ? fmax(continuousPlaybackBackgroundTransitionDuration.numberValue.doubleValue, 0.) : SRGLetterboxContinuousPlaybackDisabled;
    
    FIRRemoteConfigValue *endTolerance = [self.remoteConfig configValueForKey:@"endTolerance"];
    self.endTolerance = (endTolerance.stringValue.length > 0) ? fmax(endTolerance.numberValue.doubleValue, 0.) : 0.;
    
    FIRRemoteConfigValue *endToleranceRatio = [self.remoteConfig configValueForKey:@"endToleranceRatio"];
    self.endToleranceRatio = (endToleranceRatio.stringValue.length > 0) ? fmaxf(endToleranceRatio.numberValue.floatValue, 0.f) : 0.f;
    
    self.hiddenOnboardingUids = [[self.remoteConfig configValueForKey:@"hiddenOnboardings"].stringValue componentsSeparatedByString:@","];
    
    self.searchSettingsHidden = [self.remoteConfig configValueForKey:@"searchSettingsHidden"].boolValue;
    self.searchSettingSubtitledHidden = [self.remoteConfig configValueForKey:@"searchSettingSubtitledHidden"].boolValue;
    self.showsSearchHidden = [self.remoteConfig configValueForKey:@"showsSearchHidden"].boolValue;
    
    self.logoutMenuEnabled = [self.remoteConfig configValueForKey:@"logoutMenuEnabled"].boolValue;
    
    [NSNotificationCenter.defaultCenter postNotificationName:ApplicationConfigurationDidChangeNotification
                                                      object:self];
    
    return YES;
}

#pragma mark Getter

- (NSURL *)playURL
{
    NSURL *playURL = _playURL;
#if defined(DEBUG) || defined(NIGHTLY) || defined(BETA)
    if (self.overridePlayURL) {
        playURL = self.overridePlayURL;
    }
#endif
    return playURL;
}

#pragma mark Helpers

- (RadioChannel *)radioChannelForUid:(NSString *)uid
{
    if (! uid) {
        return nil;
    }
    
    return [self.radioChannels filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"%K == %@", @keypath(RadioChannel.new, uid), uid]].firstObject;
}

- (TVChannel *)tvChannelForUid:(NSString *)uid
{
    if (! uid) {
        return nil;
    }
    
    return [self.tvChannels filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"%K == %@", @keypath(TVChannel.new, uid), uid]].firstObject;
}

- (NSURL *)imageURLForTopicUid:(NSString *)uid
{
    NSString *URLString = self.topicHeaders[uid][@"imageURL"];
    return URLString ? [NSURL URLWithString:URLString] : nil;
}

- (NSString *)imageTitleForTopicUid:(NSString *)uid
{
    return self.topicHeaders[uid][@"imageTitle"];
}
- (NSString *)imageCopyrightForTopicUid:(NSString *)uid
{
    return self.topicHeaders[uid][@"imageCopyright"];
}

- (NSURL *)sharingURLForMediaMetadata:(id<SRGMediaMetadata>)mediaMetadata atTime:(CMTime)time;
{
    if (PlayIsSwissTXTURN(mediaMetadata.URN)) {
        return [NSURL URLWithString:[NSString stringWithFormat:@"https://tp.srgssr.ch/p/livecenter?urn=%@", mediaMetadata.URN]];
    }
    else {
        if (! self.playURL) {
            return nil;
        }
        
        static NSDictionary<NSNumber *, NSString *> *s_mediaTypeNames;
        static dispatch_once_t s_onceToken;
        dispatch_once(&s_onceToken, ^{
            s_mediaTypeNames = @{ @(SRGMediaTypeVideo) : @"tv",
                                  @(SRGMediaTypeAudio) : @"radio" };
        });
        
        NSString *mediaTypeName = s_mediaTypeNames[@(mediaMetadata.mediaType)];
        if (! mediaTypeName) {
            return nil;
        }
        
        NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:self.playURL resolvingAgainstBaseURL:NO];
        URLComponents.path = [[[[URLComponents.path stringByAppendingPathComponent:mediaTypeName]
                                stringByAppendingPathComponent:@"redirect"]
                               stringByAppendingPathComponent:@"detail"]
                              stringByAppendingPathComponent:mediaMetadata.uid];
        
        NSInteger position = CMTimeGetSeconds(time);
        if (position > 0) {
            NSArray<NSURLQueryItem *> *queryItems = URLComponents.queryItems ?: @[];
            queryItems = [queryItems arrayByAddingObject:[NSURLQueryItem queryItemWithName:@"startTime" value:@(position).stringValue]];
            URLComponents.queryItems = queryItems;
        }
        
        return URLComponents.URL;
    }
}

- (NSURL *)sharingURLForShow:(SRGShow *)show
{
    if (! self.playURL || ! show) {
        return nil;
    }
    
    static NSDictionary<NSNumber *, NSString *> *s_showTypeNames;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        s_showTypeNames = @{ @(SRGTransmissionTV) : @"tv",
                             @(SRGTransmissionRadio) : @"radio",
                             @(SRGTransmissionOnline) : @"online" };
    });
    
    NSString *showTypeName = s_showTypeNames[@(show.transmission)];
    if (! showTypeName) {
        return nil;
    }
    
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:self.playURL resolvingAgainstBaseURL:NO];
    URLComponents.path = [[[URLComponents.path stringByAppendingPathComponent:showTypeName]
                           stringByAppendingPathComponent:@"quicklink"]
                          stringByAppendingPathComponent:show.uid];
    return URLComponents.URL;
}

- (NSURL *)sharingURLForModule:(SRGModule *)module
{
    if (! self.playURL || ! module) {
        return nil;
    }
    
    static NSDictionary<NSNumber *, NSString *> *s_moduleTypeNames;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        s_moduleTypeNames = @{ @(SRGModuleTypeEvent) : @"event" };
    });
    
    NSString *moduleTypeName = s_moduleTypeNames[@(module.moduleType)];
    if (! moduleTypeName) {
        return nil;
    }
    
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:self.playURL resolvingAgainstBaseURL:NO];
    URLComponents.path = [[[URLComponents.path stringByAppendingPathComponent:@"tv"]
                           stringByAppendingPathComponent:moduleTypeName]
                          stringByAppendingPathComponent:module.seoName];
    return URLComponents.URL;
}

- (NSArray<NSNumber *> *)homeSectionsFromString:(NSString *)homeSectionsString
{
    NSMutableArray<NSNumber *> *homeSections = [NSMutableArray array];
    if (homeSectionsString.length != 0) {
        NSArray<NSString *> *homeSectionIdentifiers = [homeSectionsString componentsSeparatedByString:@","];
        for (NSString *identifier in homeSectionIdentifiers) {
            HomeSection homeSection = HomeSectionWithString(identifier);
            if (homeSection != HomeSectionUnknown) {
                [homeSections addObject:@(homeSection)];
            }
            else {
                PlayLogWarning(@"configuration", @"Unknown home section identifier %@. Skipped.", identifier);
            }
        }
    }
    return homeSections.copy;
}

#pragma mark Notifications

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    [self update];
}

#pragma mark Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; videoHomeSections = %@; liveHomeSections = %@; radioChannels = %@; audioHomeSections = %@>",
            self.class,
            self,
            self.videoHomeSections,
            self.liveHomeSections,
            self.radioChannels,
            self.audioHomeSections];
}

@end
