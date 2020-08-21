//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import SRGDataProviderCombine

/**
 *  Abstract base class for homepage rows.
 */
class HomeRow: Identifiable, Equatable {
    /**
     *  The appearance to apply to the row.
     */
    enum Appearance: Equatable {
        case `default`
        case hero
    }
    
    /**
     *  The row identifier.
     */
    enum Id: Equatable {
        case tvTrending(appearance: Appearance)
        case tvLatest
        case tvMostPopular
        case tvSoonExpiring
        case tvLatestForTopic(_ topic: SRGTopic?)
        case tvLatestForModule(_ module: SRGModule?, type: SRGModuleType)
        case tvTopicsAccess
        case tvShowsAccess
        
        case radioLatestEpisodes(channelUid: String)
        case radioMostPopular(channelUid: String)
        case radioLatest(channelUid: String)
        case radioLatestVideos(channelUid: String)
        case radioAllShows(channelUid: String)
        case radioShowsAccess(channelUid: String)
        
        case tvLive
        case radioLive
        case radioLiveSatellite
        
        case tvLiveCenter
        case tvScheduledLivestreams
    }
    
    /**
     *  Row factory method.
     */
    static func makeRow(for id: Id) -> HomeRow {
        switch id {
            case .tvTopicsAccess:
                return HomeTopicsAccessRow(id: id)
            case .tvShowsAccess, .radioShowsAccess:
                return HomeShowsAccessRow(id: id)
            case .radioAllShows:
                return HomeRadioShowsRow(id: id)
            default:
                return HomeMediaRow(id: id)
        }
    }
    
    final let id: Id
    
    var title: String? {
        return nil
    }
    
    func load() -> AnyCancellable? {
        return nil
    }
    
    init(id: Id) {
        self.id = id
    }
    
    static func == (lhs: HomeRow, rhs: HomeRow) -> Bool {
        return lhs.id == rhs.id
    }
}

final class HomeMediaRow: HomeRow, ObservableObject {
    @Published private(set) var medias: [SRGMedia] = []
    
    override var title: String? {
        switch id {
            case .tvTrending:
                return "Trending videos"
            case .tvLatest:
                return "The latest episodes"
            case .tvMostPopular:
                return "Most popular"
            case .tvSoonExpiring:
                return "Available for a limited time"
            case let .tvLatestForModule(module, type):
                if let module = module {
                    return module.title
                }
                else {
                    return Self.moduleTitle(for: type)
                }
            case let .tvLatestForTopic(topic):
                return topic?.title ?? "Topic"
            case .radioLatestEpisodes:
                return "The latest audios"
            case .radioMostPopular:
                return "Most listened to"
            case .radioLatest:
                return "The latest audios"
            case .radioLatestVideos:
                return "Latest videos"
            case .tvLive:
                return "TV channels"
            case .radioLive:
                return "Radio channels"
            case .radioLiveSatellite:
                return "Thematic radios"
            case .tvLiveCenter:
                return "Sport"
            case .tvScheduledLivestreams:
                return "Events"
            default:
                return nil
        }
    }
    
    override func load() -> AnyCancellable? {
        return mediasPublisher()?
            .map(\.medias)
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .assign(to: \.medias, on: self)
    }
    
    private typealias Output = (medias: [SRGMedia], response: URLResponse)
    
    private func mediasPublisher() -> AnyPublisher<Output, Error>? {
        let dataProvider = SRGDataProvider.current!
        let configuration = ApplicationConfiguration.shared
        
        let vendor = configuration.vendor
        let pageSize = configuration.pageSize
        
        switch id {
            case .tvTrending:
                return dataProvider.tvTrendingMedias(for: vendor, limit: pageSize, editorialLimit: configuration.tvTrendingEditorialLimit?.uintValue,
                                                     episodesOnly: configuration.tvTrendingEpisodesOnly)
            case .tvLatest:
                return dataProvider.tvLatestMedias(for: vendor, pageSize: pageSize)
                    .map { ($0.medias, $0.response) }
                    .eraseToAnyPublisher()
            case .tvMostPopular:
                return dataProvider.tvMostPopularMedias(for: vendor, pageSize: pageSize)
                    .map { ($0.medias, $0.response) }
                    .eraseToAnyPublisher()
            case .tvSoonExpiring:
                return dataProvider.tvSoonExpiringMedias(for: vendor, pageSize: pageSize)
                    .map { ($0.medias, $0.response) }
                    .eraseToAnyPublisher()
            case let .tvLatestForModule(module, type: _):
                guard let urn = module?.urn else { return nil }
                return dataProvider.latestMediasForModule(withUrn: urn, pageSize: pageSize)
                    .map { ($0.medias, $0.response) }
                    .eraseToAnyPublisher()
            case let .tvLatestForTopic(topic):
                guard let urn = topic?.urn else { return nil }
                return dataProvider.latestMediasForTopic(withUrn: urn, pageSize: pageSize)
                    .map { ($0.medias, $0.response) }
                    .eraseToAnyPublisher()
            case let .radioLatestEpisodes(channelUid: channelUid):
                return dataProvider.radioLatestEpisodes(for: vendor, channelUid: channelUid, pageSize: pageSize)
                    .map { ($0.medias, $0.response) }
                    .eraseToAnyPublisher()
            case let .radioMostPopular(channelUid: channelUid):
                return dataProvider.radioMostPopularMedias(for: vendor, channelUid: channelUid, pageSize: pageSize)
                    .map { ($0.medias, $0.response) }
                    .eraseToAnyPublisher()
            case let .radioLatest(channelUid: channelUid):
                return dataProvider.radioLatestMedias(for: vendor, channelUid: channelUid, pageSize: pageSize)
                    .map { ($0.medias, $0.response) }
                    .eraseToAnyPublisher()
            case let .radioLatestVideos(channelUid: channelUid):
                return dataProvider.radioLatestVideos(for: vendor, channelUid: channelUid, pageSize: pageSize)
                    .map { ($0.medias, $0.response) }
                    .eraseToAnyPublisher()
            case .tvLive:
                return dataProvider.tvLivestreams(for: vendor)
            case .radioLive:
                return dataProvider.radioLivestreams(for: vendor, contentProviders: .default)
            case .radioLiveSatellite:
                return dataProvider.radioLivestreams(for: vendor, contentProviders: .swissSatelliteRadio)
            case .tvLiveCenter:
                return dataProvider.liveCenterVideos(for: vendor, pageSize: pageSize)
                    .map { ($0.medias, $0.response) }
                    .eraseToAnyPublisher()
            case .tvScheduledLivestreams:
                return dataProvider.tvScheduledLivestreams(for: vendor, pageSize: pageSize)
                    .map { ($0.medias, $0.response) }
                    .eraseToAnyPublisher()
            default:
                return nil
        }
    }
    
    private static func moduleTitle(for type: SRGModuleType) -> String {
        return type == .event ? "Event" : "Module"
    }
}

final class HomeTopicsAccessRow: HomeRow, ObservableObject {
    @Published private(set) var topics: [SRGTopic] = []
    
    override func load() -> AnyCancellable? {
        switch id {
            case .tvTopicsAccess:
                return SRGDataProvider.current!.tvTopics(for: ApplicationConfiguration.shared.vendor)
                    .map(\.topics)
                    .replaceError(with: [])
                    .receive(on: DispatchQueue.main)
                    .assign(to: \.topics, on: self)
            default:
                return nil;
        }
    }
}

final class HomeRadioShowsRow: HomeRow, ObservableObject {
    @Published private(set) var shows: [SRGShow] = []
    
    override var title: String? {
        switch id {
            case .radioAllShows:
                return "Shows"
            default:
                return nil
        }
    }
    
    override func load() -> AnyCancellable? {
        switch id {
            case let .radioAllShows(channelUid):
                return SRGDataProvider.current!.radioShows(for: ApplicationConfiguration.shared.vendor, channelUid: channelUid, pageSize: SRGDataProviderUnlimitedPageSize)
                    .map(\.shows)
                    .replaceError(with: [])
                    .receive(on: DispatchQueue.main)
                    .assign(to: \.shows, on: self)
            default:
                return nil;
        }
    }
}

final class HomeShowsAccessRow: HomeRow {
    override var title: String? {
        return "Shows"
    }
}
