//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, HomeSection) {
    HomeSectionUnknown = 0,
    
    // TV sections
    HomeSectionTVTrending,
    HomeSectionTVEvents,
    HomeSectionTVTopics,
    HomeSectionTVTopicsAccess,
    HomeSectionTVLatest,
    HomeSectionTVWebFirst,
    HomeSectionTVMostPopular,
    HomeSectionTVSoonExpiring,
    HomeSectionTVShowsAccess,
    HomeSectionTVFavoriteShows,
    HomeSectionTVFavoriteLatestEpisodes API_AVAILABLE(tvos(14.0)) API_UNAVAILABLE(ios),
    HomeSectionTVResumePlayback API_AVAILABLE(tvos(14.0)) API_UNAVAILABLE(ios),
    HomeSectionTVWatchLater API_AVAILABLE(tvos(14.0)) API_UNAVAILABLE(ios),
    
    // Radio sections
    HomeSectionRadioLatestEpisodes,
    HomeSectionRadioMostPopular,
    HomeSectionRadioLatest,
    HomeSectionRadioLatestVideos,
    HomeSectionRadioAllShows,
    HomeSectionRadioShowsAccess,
    HomeSectionRadioFavoriteShows,
    
    // Live sections
    HomeSectionTVLive,
    HomeSectionRadioLive,
    HomeSectionRadioLiveSatellite,
    HomeSectionTVLiveCenter,
    HomeSectionTVScheduledLivestreams
};

OBJC_EXPORT NSString *TitleForHomeSection(HomeSection homeSection);

NS_ASSUME_NONNULL_END
