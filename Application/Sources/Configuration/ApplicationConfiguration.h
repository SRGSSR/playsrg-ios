//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#import <SRGAnalytics/SRGAnalytics.h>
#import <SRGDataProvider/SRGDataProvider.h>
#import <SRGLetterbox/SRGLetterbox.h>

#import "RadioChannel.h"
#import "TVChannel.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, HomeSection) {
    HomeSectionUnknown,
    
    // TV sections
    HomeSectionTVTrending,
    HomeSectionTVLive,
    HomeSectionTVEvents,
    HomeSectionTVTopics,
    HomeSectionTVLatest,
    HomeSectionTVMostPopular,
    HomeSectionTVSoonExpiring,
    HomeSectionTVScheduledLivestreams,
    HomeSectionTVLiveCenter,
    HomeSectionTVShowsAccess,
    HomeSectionTVFavoriteShows,
    
    // Radio sections
    HomeSectionRadioLive,
    HomeSectionRadioLatestEpisodes,
    HomeSectionRadioMostPopular,
    HomeSectionRadioLatest,
    HomeSectionRadioLatestVideos,
    HomeSectionRadioAllShows,
    HomeSectionRadioShowsAccess,
    HomeSectionRadioFavoriteShows
};

typedef NS_ENUM(NSInteger, TopicSection) {
    TopicSectionUnknown,
    TopicSectionLatest,
    TopicSectionMostPopular
};

typedef NS_ENUM(NSInteger, MenuItem) {
    MenuItemUnknown,
    
    MenuItemSearch,
    MenuItemFavorites,
    MenuItemWatchLater,
    MenuItemDownloads,
    MenuItemHistory,
    MenuItemNotifications,
    
    MenuItemTVOverview,
    MenuItemTVByDate,
    MenuItemTVShowAZ,
    
    MenuItemRadio,
    MenuItemRadioShowAZ,
    
    MenuItemFeedback,
    MenuItemSettings,
    MenuItemHelp
};

OBJC_EXPORT NSString *TitleForHomeSection(HomeSection homeSection);
OBJC_EXPORT NSString *TitleForMenuItem(MenuItem menuItem);
OBJC_EXPORT NSString *TitleForTopicSection(TopicSection topicSection);

OBJC_EXPORT void ApplicationConfigurationApplyControllerSettings(SRGLetterboxController *controller);
OBJC_EXPORT NSTimeInterval ApplicationConfigurationEffectiveEndTolerance(NSTimeInterval duration);

OBJC_EXPORT NSString * const ApplicationConfigurationDidChangeNotification;

@interface ApplicationConfiguration : NSObject

@property (class, nonatomic, readonly) ApplicationConfiguration *sharedApplicationConfiguration;

@property (nonatomic, readonly) SRGVendor vendor;

@property (nonatomic, readonly, copy) SRGAnalyticsBusinessUnitIdentifier analyticsBusinessUnitIdentifier;
@property (nonatomic, readonly) NSInteger analyticsContainer;

@property (nonatomic, readonly, copy) NSString *comScoreVirtualSite;
@property (nonatomic, readonly, copy) NSString *netMetrixIdentifier;

// Might be nil for "exotic" languages like Rumantsch
@property (nonatomic, readonly, copy, nullable) NSString *voiceOverLanguageCode;

@property (nonatomic, readonly, copy) NSString *googleCastReceiverIdentifier;
@property (nonatomic, readonly, copy) NSNumber *appStoreProductIdentifier;

@property (nonatomic, readonly) NSURL *playURL;
@property (nonatomic, readonly) NSURL *middlewareURL;
@property (nonatomic, readonly, nullable) NSURL *identityWebserviceURL;
@property (nonatomic, readonly, nullable) NSURL *identityWebsiteURL;
@property (nonatomic, readonly, nullable) NSURL *userDataServiceURL;

@property (nonatomic, readonly) NSURL *whatsNewURL;
@property (nonatomic, readonly, nullable) NSURL *feedbackURL;
@property (nonatomic, readonly, nullable) NSURL *impressumURL;
@property (nonatomic, readonly, nullable) NSURL *termsAndConditionsURL;
@property (nonatomic, readonly, nullable) NSURL *dataProtectionURL;
@property (nonatomic, readonly, nullable) NSURL *betaTestingURL;
@property (nonatomic, readonly, nullable) NSURL *sourceCodeURL;

@property (nonatomic, readonly, getter=areDownloadsHintsHidden) BOOL downloadsHintsHidden;
@property (nonatomic, readonly, getter=areMoreEpisodesHidden) BOOL moreEpisodesHidden;
@property (nonatomic, readonly, getter=areModuleColorsDisabled) BOOL moduleColorsDisabled;

@property (nonatomic, readonly, getter=isSubtitleAvailabilityHidden) BOOL subtitleAvailabilityHidden;
@property (nonatomic, readonly, getter=isAudioDescriptionAvailabilityHidden) BOOL audioDescriptionAvailabilityHidden;

@property (nonatomic, readonly) UIColor *moduleDefaultLinkColor;
@property (nonatomic, readonly) UIColor *moduleDefaultTextColor;

@property (nonatomic, readonly) NSArray<NSNumber *> *tvMenuItems;                       // wrap `MenuItem` values

@property (nonatomic, readonly) NSArray<NSNumber *> *videoSections;
@property (nonatomic, readonly) NSArray<NSNumber *> *liveSections;

@property (nonatomic, readonly) BOOL tvTrendingEpisodesOnly;
@property (nonatomic, readonly, nullable) NSNumber *tvTrendingEditorialLimit;

@property (nonatomic, readonly, getter=isTvFeaturedHomeSectionHeaderHidden) BOOL tvFeaturedHomeSectionHeaderHidden;

// The number of placeholders to be displayed while loading TV channels
@property (nonatomic, readonly) NSInteger tvNumberOfLivePlaceholders;

@property (nonatomic, readonly) NSInteger minimumSocialViewCount;                       // minimum value to display social view count

@property (nonatomic, readonly) NSArray<NSNumber *> *topicSections;                     // wrap `TopicSection` values
@property (nonatomic, readonly) NSArray<NSNumber *> *topicSectionsWithSubtopics;        // wrap `TopicSection` values

@property (nonatomic, readonly) NSArray<RadioChannel *> *radioChannels;
@property (nonatomic, readonly) NSArray<TVChannel *> *tvChannels;

@property (nonatomic, readonly, getter=isRadioFeaturedHomeSectionHeaderHidden) BOOL radioFeaturedHomeSectionHeaderHidden;

@property (nonatomic, readonly) NSArray<NSNumber *> *radioMenuItems;                    // wrap `MenuItem` values

@property (nonatomic, readonly) NSUInteger pageSize;                                    // page size to be used in general throughout the app

@property (nonatomic, readonly, getter=isContinuousPlaybackAvailable) BOOL continuousPlaybackAvailable;

@property (nonatomic, readonly) NSTimeInterval continuousPlaybackPlayerViewTransitionDuration;      // If the remote config is empty, returns `SRGLetterboxContinuousPlaybackDisabled`
@property (nonatomic, readonly) NSTimeInterval continuousPlaybackForegroundTransitionDuration;      // If the remote config is empty, returns `SRGLetterboxContinuousPlaybackDisabled`
@property (nonatomic, readonly) NSTimeInterval continuousPlaybackBackgroundTransitionDuration;      // If the remote config is empty, returns `SRGLetterboxContinuousPlaybackDisabled`

@property (nonatomic, readonly) NSTimeInterval endTolerance;
@property (nonatomic, readonly) float endToleranceRatio;

@property (nonatomic, readonly) NSArray<NSString *> *hiddenOnboardingUids;

@property (nonatomic, readonly, getter=isLogoutMenuEnabled) BOOL logoutMenuEnabled;

@property (nonatomic, readonly, getter=areSearchSettingsHidden) BOOL searchSettingsHidden;
@property (nonatomic, readonly, getter=isSearchSettingSubtitledHidden) BOOL searchSettingSubtitledHidden;
@property (nonatomic, readonly, getter=isShowsSearchHidden) BOOL showsSearchHidden;

- (nullable RadioChannel *)radioChannelForUid:(NSString *)uid;
- (nullable TVChannel *)tvChannelForUid:(NSString *)uid;

- (nullable NSURL *)imageURLForTopicUid:(NSString *)uid;
- (nullable NSString *)imageTitleForTopicUid:(NSString *)uid;
- (nullable NSString *)imageCopyrightForTopicUid:(NSString *)uid;

/**
 *  URLs to be used for sharing
 */
- (nullable NSURL *)sharingURLForMediaMetadata:(id<SRGMediaMetadata>)mediaMetadata atTime:(CMTime)time; // Use kCMTimeZero to start at the default location.
- (nullable NSURL *)sharingURLForShow:(SRGShow *)show;
- (nullable NSURL *)sharingURLForModule:(SRGModule *)module;

#if defined(DEBUG) || defined(NIGHTLY) || defined(BETA)

/**
 *  An optionnal override play URL for test and stage environnements. Use `playURL` property to get the current URL.
 */
- (void)setOverridePlayURL:(nullable NSURL *)overridePlayURL;

#endif

@end

NS_ASSUME_NONNULL_END
