//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "ApplicationConfiguration.h"

#import <SRGLetterbox/SRGLetterbox.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  User location options.
 */
typedef NS_ENUM(NSInteger, SettingUserLocation) {
    /**
     *  Default IP-based location.
     */
    SettingUserLocationDefault,
    /**
     *  Outside CH.
     */
    SettingUserLocationOutsideCH,
    /**
     *  Ignore location.
     */
    SettingUserLocationIgnored
};

/**
 *  Tab bar item identifier.
 */
typedef NS_ENUM(NSInteger, TabBarItemIdentifier) {
    TabBarItemIdentifierNone = 0,
    TabBarItemIdentifierVideos,
    TabBarItemIdentifierAudios,
    TabBarItemIdentifierLivestreams,
    TabBarItemIdentifierSearch,
    TabBarItemIdentifierLibrary
};

OBJC_EXPORT NSString * const PlaySRGSettingHDOverCellularEnabled;
OBJC_EXPORT NSString * const PlaySRGSettingOriginalImagesOnlyEnabled;
OBJC_EXPORT NSString * const PlaySRGSettingPresenterModeEnabled;
OBJC_EXPORT NSString * const PlaySRGSettingStandaloneEnabled;
OBJC_EXPORT NSString * const PlaySRGSettingAutoplayEnabled;
OBJC_EXPORT NSString * const PlaySRGSettingBackgroundVideoPlaybackEnabled;
OBJC_EXPORT NSString * const PlaySRGSettingSubtitleAvailabilityDisplayed;
OBJC_EXPORT NSString * const PlaySRGSettingAudioDescriptionAvailabilityDisplayed;

OBJC_EXPORT NSString * const PlaySRGSettingLastLoggedInEmailAddress;
OBJC_EXPORT NSString * const PlaySRGSettingServiceURL;
OBJC_EXPORT NSString * const PlaySRGSettingUserLocation;

OBJC_EXPORT BOOL ApplicationSettingAlternateRadioHomepageDesignEnabled(void);
OBJC_EXPORT BOOL ApplicationSettingOriginalImagesOnlyEnabled(void);
OBJC_EXPORT BOOL ApplicationSettingPresenterModeEnabled(void);

OBJC_EXPORT BOOL ApplicationSettingStandaloneEnabled(void);
OBJC_EXPORT SRGQuality ApplicationSettingPreferredQuality(void);
OBJC_EXPORT SRGLetterboxPlaybackSettings *ApplicationSettingPlaybackSettings(void);

OBJC_EXPORT NSURL *ApplicationSettingServiceURL(void);
OBJC_EXPORT void ApplicationSettingSetServiceURL(NSURL * _Nullable serviceURL);

OBJC_EXPORT NSDictionary<NSString *, NSString *> *ApplicationSettingGlobalParameters(void);
OBJC_EXPORT NSTimeInterval ApplicationSettingContinuousPlaybackTransitionDuration(void);

OBJC_EXPORT BOOL ApplicationSettingBackgroundVideoPlaybackEnabled(void);

OBJC_EXPORT BOOL ApplicationSettingSubtitleAvailabilityDisplayed(void);
OBJC_EXPORT BOOL ApplicationSettingAudioDescriptionAvailabilityDisplayed(void);

OBJC_EXPORT NSString * _Nullable ApplicationSettingSelectedLiveStreamURNForChannelUid(NSString * _Nullable channelUid);
OBJC_EXPORT void ApplicationSettingSetSelectedLiveStreamURNForChannelUid(NSString * channelUid, NSString * _Nullable mediaURN);

OBJC_EXPORT SRGMedia * _Nullable ApplicationSettingSelectedLivestreamMediaForChannelUid(NSString * _Nullable channelUid, NSArray<SRGMedia *> * _Nullable medias);

OBJC_EXPORT TabBarItemIdentifier ApplicationSettingLastOpenedTabBarItemIdentifier(void);
OBJC_EXPORT void ApplicationSettingSetLastOpenedTabBarItemIdentifier(TabBarItemIdentifier tabBarItemIdentifier);

OBJC_EXPORT RadioChannel * _Nullable ApplicationSettingLastOpenedRadioChannel(void);
OBJC_EXPORT void ApplicationSettingSetLastOpenedRadioChannel(RadioChannel * radioChannel);

OBJC_EXPORT HomeSection ApplicationSettingLastOpenedLivestreamHomeSection(void);
OBJC_EXPORT void ApplicationSettingSetLastOpenedLivestreamHomeSection(HomeSection homeSection);

OBJC_EXPORT NSURL * _Nullable ApplicationSettingServiceURLForKey(NSString *key);
OBJC_EXPORT NSString * _Nullable ApplicationSettingServiceNameForKey(NSString *key);

OBJC_EXPORT BOOL ApplicationSettingBackgroundVideoPlaybackEnabled(void);

NS_ASSUME_NONNULL_END
