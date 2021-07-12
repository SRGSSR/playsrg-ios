//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

extension ApplicationConfiguration {
    private static func configuredSection(from homeSection: HomeSection) -> ConfiguredSection? {
        switch homeSection {
        case .tvLive:
            return .tvLive
        case .radioLive:
            return .radioLive
        case .radioLiveSatellite:
            return .radioLiveSatellite
        case .tvLiveCenter:
            return .tvLiveCenter
        case .tvScheduledLivestreams:
            return .tvScheduledLivestreams
        default:
            return nil
        }
    }
    
    func liveConfiguredSections() -> [ConfiguredSection] {
        return liveHomeSections.compactMap { homeSection in
            guard let homeSection = HomeSection(rawValue: homeSection.intValue) else { return nil }
            return Self.configuredSection(from: homeSection)
        }
    }
}

enum ConfiguredSection: Hashable {
    case show(SRGShow)
    
    case favoriteShows
    case history
    case watchLater
    
    case tvAllShows
    case tvEpisodesForDay(_ day: SRGDay)
    
    case radioAllShows(channelUid: String)
    case radioEpisodesForDay(_ day: SRGDay, channelUid: String)
    case radioFavoriteShows(channelUid: String)
    case radioLatest(channelUid: String)
    case radioLatestEpisodes(channelUid: String)
    case radioLatestEpisodesFromFavorites(channelUid: String)
    case radioLatestVideos(channelUid: String)
    case radioMostPopular(channelUid: String)
    case radioResumePlayback(channelUid: String)
    case radioShowAccess(channelUid: String)
    case radioWatchLater(channelUid: String)
    
    case tvLive
    case radioLive
    case radioLiveSatellite
    
    case tvLiveCenter
    case tvScheduledLivestreams
}
