//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

extension ApplicationConfiguration {
    private static func livePlaySectionType(from homeSection: HomeSection) -> PlaySection.`Type`? {
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
    
    func liveHomePlaySections() -> [PlaySection] {
        var playSections = [PlaySection]()
        for homeSection in liveHomeSections {
            if let homeSection = HomeSection(rawValue: homeSection.intValue),
               let playSectionType = Self.livePlaySectionType(from: homeSection) {
                playSections.append(PlaySection(type: playSectionType, contentPresentationType: .livestreams))
            }
        }
        return playSections
    }
}

struct PlaySection: Hashable {
    enum `Type`: Hashable {
        case radioLatestEpisodes(channelUid: String)
        case radioMostPopular(channelUid: String)
        case radioLatest(channelUid: String)
        case radioLatestVideos(channelUid: String)
        case radioAllShows(channelUid: String)
        case radioFavoriteShows(channelUid: String)
        case radioShowAccess(channelUid: String)
        
        case tvLive
        case radioLive
        case radioLiveSatellite
        
        case tvLiveCenter
        case tvScheduledLivestreams
    }
    
    let type: Type
    let contentPresentationType: SRGContentPresentationType
}
