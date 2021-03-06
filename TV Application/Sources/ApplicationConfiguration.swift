//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import SRGDataProviderModel

extension ApplicationConfiguration {
    private func videoHomeRowId(from homeSection: HomeSection) -> HomeModel.RowId? {
        switch homeSection {
        case .tvTrending:
            return .tvTrending(appearance: .hero)
        case .tvFavoriteShows:
            return .tvFavoriteShows
        case .tvFavoriteLatestEpisodes:
            return .tvFavoriteLatestEpisodes
        case .tvLatest:
            return .tvLatest
        case .tvWebFirst:
            return .tvWebFirst
        case .tvMostPopular:
            return .tvMostPopular
        case .tvSoonExpiring:
            return .tvSoonExpiring
        case .tvEvents:
            return .tvLatestForModule(nil, type: .event)
        case .tvTopics:
            return .tvLatestForTopic(nil)
        case .tvTopicsAccess:
            return .tvTopicsAccess
        case .tvResumePlayback:
            return .tvResumePlayback
        case .tvWatchLater:
            return .tvWatchLater
        default:
            return nil
        }
    }
    
    private func liveHomeRowId(from homeSection: HomeSection) -> HomeModel.RowId? {
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
    
    func videoHomeRowIds() -> [HomeModel.RowId] {
        var rowIds = [HomeModel.RowId]()
        for homeSection in videoHomeSections {
            if let homeSection = HomeSection(rawValue: homeSection.intValue),
               let rowId = videoHomeRowId(from: homeSection) {
                rowIds.append(rowId)
            }
        }
        return rowIds
    }
    
    func liveHomeRowIds() -> [HomeModel.RowId] {
        var rowIds = [HomeModel.RowId]()
        for homeSection in liveHomeSections {
            if let homeSection = HomeSection(rawValue: homeSection.intValue),
               let rowId = liveHomeRowId(from: homeSection) {
                rowIds.append(rowId)
            }
        }
        return rowIds
    }
}
