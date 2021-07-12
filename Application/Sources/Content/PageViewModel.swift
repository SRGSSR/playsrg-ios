//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import SRGDataProviderCombine

// MARK: View model

class PageViewModel: Identifiable, ObservableObject {
    let id: Id
    
    var title: String? {
        switch id {
        case .video, .audio, .live:
            return nil
        case let .topic(topic: topic):
            return topic.title
        }
    }
    
    @Published private(set) var state: State = .loading
    @Published private(set) var serviceStatus: ServiceStatus = .good
    
    private let trigger = Trigger()
    private var cancellables = Set<AnyCancellable>()
    
    init(id: Id) {
        self.id = id
        
        Publishers.PublishAndRepeat(onOutputFrom: trigger.signal(activatedBy: TriggerId.reload)) { [weak self] in
            return SRGDataProvider.current!.sectionsPublisher(id: id)
                .map { sections in
                    return Publishers.AccumulateLatestMany(sections.map { section in
                        return Publishers.PublishAndRepeat(onOutputFrom: Self.rowReloadSignal(for: section, trigger: self?.trigger)) {
                            return SRGDataProvider.current!.rowPublisher(id: id,
                                                                         section: section,
                                                                         pageSize: Self.pageSize(for: section, in: sections),
                                                                         paginatedBy: self?.trigger.signal(activatedBy: TriggerId.loadMore(section: section))
                            )
                            .replaceError(with: Self.placeholderRow(for: section, state: self?.state))
                            .prepend(Self.placeholderRow(for: section, state: self?.state))
                            .eraseToAnyPublisher()
                        }
                    })
                    .eraseToAnyPublisher()
                }
                .switchToLatest()
                .map { State.loaded(rows: $0.filter { !$0.isEmpty }) }
                .catch { error in
                    return Just(State.failed(error: error))
                }
                .eraseToAnyPublisher()
        }
        .receive(on: DispatchQueue.main)
        .assign(to: &$state)
        
        Publishers.PublishAndRepeat(onOutputFrom: trigger.signal(activatedBy: TriggerId.reload)) { [weak self] in
            return SRGDataProvider.current!.serviceMessage(for: ApplicationConfiguration.shared.vendor)
                .map { ServiceStatus.bad($0) }
                .replaceError(with: self?.serviceStatus ?? .good)
                .eraseToAnyPublisher()
        }
        .receive(on: DispatchQueue.main)
        .assign(to: &$serviceStatus)
        
        Signal.wokenUp()
            .sink { [weak self] in
                self?.reload()
            }
            .store(in: &cancellables)
    }
    
    func loadMore() {
        if let lastSection = state.sections.last, Self.hasLoadMore(for: lastSection, in: state.sections) {
            trigger.activate(for: TriggerId.loadMore(section: lastSection))
        }
    }
    
    func reload(deep: Bool = false) {
        if deep || state.sections.isEmpty {
            trigger.activate(for: TriggerId.reload)
        }
        else {
            for section in state.sections where !Self.hasLoadMore(for: section, in: state.sections) {
                trigger.activate(for: TriggerId.reloadSection(section))
            }
        }
    }
    
    private static func rowReloadSignal(for section: PageViewModel.Section, trigger: Trigger?) -> AnyPublisher<Void, Never> {
        return Publishers.Merge(
            section.properties.reloadSignal() ?? PassthroughSubject<Void, Never>().eraseToAnyPublisher(),
            trigger?.signal(activatedBy: PageViewModel.TriggerId.reloadSection(section)) ?? PassthroughSubject<Void, Never>().eraseToAnyPublisher()
        )
        .eraseToAnyPublisher()
    }
    
    private static func hasLoadMore(for section: Section, in sections: [Section]) -> Bool {
        if section == sections.last && section.viewModelProperties.hasGridLayout {
            return true
        }
        else {
            return false
        }
    }
    
    private static func pageSize(for section: Section, in sections: [Section]) -> UInt {
        let configuration = ApplicationConfiguration.shared
        return hasLoadMore(for: section, in: sections) ? configuration.detailPageSize : configuration.pageSize
    }
    
    private static func placeholderRow(for section: Section, state: State?) -> Row {
        if let row = state?.rows.first(where: { $0.section == section }) {
            return row
        }
        else {
            return PageViewModel.Row(section: section, items: Self.placeholderRowItems(for: section))
        }
    }
    
    private static func placeholderRowItems(for section: Section) -> [Item] {
        return section.properties.placeholderItems.map { Item(.item($0), in: section) }
    }
}

// MARK: Types

extension PageViewModel {
    enum Id: SectionFiltering {
        case video
        case audio(channel: RadioChannel)
        case live
        case topic(topic: SRGTopic)
        
        var supportsCastButton: Bool {
            switch self {
            case .video, .audio, .live:
                return true
            default:
                return false
            }
        }
        
        func canContain(show: SRGShow) -> Bool {
            switch self {
            case .video:
                return show.transmission == .TV
            case let .audio(channel: channel):
                return show.transmission == .radio && show.primaryChannelUid == channel.uid
            default:
                return false
            }
        }
        
        func compatibleShows(_ shows: [SRGShow]) -> [SRGShow] {
            return shows.filter { canContain(show: $0) }
        }
        
        func compatibleMedias(_ medias: [SRGMedia]) -> [SRGMedia] {
            switch self {
            case .video:
                return medias.filter { $0.mediaType == .video }
            case let .audio(channel: channel):
                return medias.filter { $0.mediaType == .audio && ($0.channel?.uid == channel.uid || $0.show?.primaryChannelUid == channel.uid) }
            default:
                return medias
            }
        }
    }
    
    enum State {
        case loading
        case failed(error: Error)
        case loaded(rows: [Row])
        
        var rows: [Row] {
            if case let .loaded(rows: rows) = self {
                return rows
            }
            else {
                return []
            }
        }
        
        var sections: [Section] {
            return rows.map(\.section)
        }
        
        var isEmpty: Bool {
            return rows.isEmpty
        }
    }
    
    enum ServiceStatus {
        case good
        case bad(SRGServiceMessage)
    }
    
    enum SectionLayout: Hashable {
        case hero
        case highlight
        case highlightSwimlane
        case liveMediaGrid
        case liveMediaSwimlane
        case mediaGrid
        case mediaSwimlane
        case showGrid
        case showSwimlane
        case topicSelector
        
        @available(tvOS, unavailable)
        case showAccess
    }
    
    struct Section: Hashable {
        let wrappedValue: Content.Section
        let index: Int      // TODO: Remove when all pages are configured with PAC
        
        init(_ wrappedValue: Content.Section, index: Int) {
            self.wrappedValue = wrappedValue
            self.index = index
        }
        
        var properties: SectionProperties {
            return wrappedValue.properties
        }
        
        var viewModelProperties: PageViewModelProperties {
            switch wrappedValue {
            case let .content(section):
                return ContentSectionProperties(contentSection: section)
            case let .configured(section):
                return ConfiguredSectionProperties(configuredSection: section, index: index)
            }
        }
    }
    
    struct Item: Hashable {
        enum WrappedValue: Hashable {
            case item(Content.Item)
            case more
        }
        
        let wrappedValue: WrappedValue
        let section: Section
        
        init(_ wrappedValue: WrappedValue, in section: Section) {
            self.wrappedValue = wrappedValue
            self.section = section
        }
    }
    
    typealias Row = CollectionRow<Section, Item>
    
    enum TriggerId: Hashable {
        case reload
        case reloadSection(Section)
        case loadMore(section: Section)
    }
}

// MARK: Publishers

private extension SRGDataProvider {
    func sectionsPublisher(id: PageViewModel.Id) -> AnyPublisher<[PageViewModel.Section], Error> {
        switch id {
        case .video:
            return contentPage(for: ApplicationConfiguration.shared.vendor, mediaType: .video)
                .map { $0.sections.enumeratedMap { PageViewModel.Section(.content($0), index: $1) } }
                .eraseToAnyPublisher()
        case let .topic(topic: topic):
            return contentPage(for: ApplicationConfiguration.shared.vendor, topicWithUrn: topic.urn)
                .map { $0.sections.enumeratedMap { PageViewModel.Section(.content($0), index: $1) } }
                .eraseToAnyPublisher()
        case let .audio(channel: channel):
            return Just(channel.configuredSections().enumeratedMap { PageViewModel.Section(.configured($0), index: $1) })
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        case .live:
            return Just(ApplicationConfiguration.shared.liveConfiguredSections().enumeratedMap { PageViewModel.Section(.configured($0), index: $1) })
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
    }
    
    func rowPublisher(id: PageViewModel.Id, section: PageViewModel.Section, pageSize: UInt, paginatedBy paginator: Trigger.Signal?) -> AnyPublisher<PageViewModel.Row, Error> {
        return Publishers.CombineLatest(
            section.properties.publisher(pageSize: pageSize, paginatedBy: paginator, filter: id)
                .scan([]) { $0 + $1 },
            section.properties.removalPublisher()
                .prepend(Just([]))
                .setFailureType(to: Error.self)
        )
        .map { items, removedItems in
            return items.filter { !removedItems.contains($0) }
        }
        .map { Self.rowItems(removeDuplicates(in: $0), in: section) }
        .map { PageViewModel.Row(section: section, items: $0) }
        .eraseToAnyPublisher()
    }
    
    static func rowItems(_ items: [Content.Item], in section: PageViewModel.Section) -> [PageViewModel.Item] {
        var rowItems = items.map { PageViewModel.Item(.item($0), in: section) }
        #if os(tvOS)
        if rowItems.count > 0
            && (section.viewModelProperties.canOpenDetailPage || ApplicationSettingSectionWideSupportEnabled())
            && section.viewModelProperties.hasSwimlaneLayout {
            rowItems.append(PageViewModel.Item(.more, in: section))
        }
        #endif
        return rowItems
    }
}

// MARK: Properties

protocol PageViewModelProperties {
    var layout: PageViewModel.SectionLayout { get }
    var canOpenDetailPage: Bool { get }
}

extension PageViewModelProperties {
    var hasSwimlaneLayout: Bool {
        switch layout {
        case .mediaSwimlane, .showSwimlane, .highlightSwimlane:
            return true
        default:
            return false
        }
    }
    
    var hasGridLayout: Bool {
        switch layout {
        case .mediaGrid, .showGrid, .liveMediaGrid:
            return true
        default:
            return false
        }
    }
}

private extension PageViewModel {
    struct ContentSectionProperties: PageViewModelProperties {
        let contentSection: SRGContentSection
        
        private var presentation: SRGContentPresentation {
            return contentSection.presentation
        }
        
        var layout: PageViewModel.SectionLayout {
            switch presentation.type {
            case .hero:
                return .hero
            case .mediaHighlight, .showHighlight:
                return .highlight
            case .mediaHighlightSwimlane:
                return .highlightSwimlane
            case .topicSelector:
                return .topicSelector
            case .showAccess:
                #if os(iOS)
                return .showAccess
                #else
                // Not supported
                return .mediaSwimlane
                #endif
            case .favoriteShows:
                return .showSwimlane
            case .swimlane:
                return (contentSection.type == .shows) ? .showSwimlane : .mediaSwimlane
            case .grid:
                return (contentSection.type == .shows) ? .showGrid : .mediaGrid
            case .livestreams:
                return .liveMediaSwimlane
            case .none, .resumePlayback, .watchLater, .personalizedProgram:
                return .mediaSwimlane
            }
        }
        
        var canOpenDetailPage: Bool {
            switch presentation.type {
            case .favoriteShows, .resumePlayback, .watchLater, .personalizedProgram:
                return true
            default:
                return presentation.hasDetailPage
            }
        }
    }
    
    struct ConfiguredSectionProperties: PageViewModelProperties {
        let configuredSection: ConfiguredSection
        let index: Int      // TODO: Remove when all pages are configured with PAC
        
        var layout: PageViewModel.SectionLayout {
            switch configuredSection {
            case .radioLatestEpisodes, .radioMostPopular, .radioLatest, .radioLatestVideos:
                return index == 0 ? .hero : .mediaSwimlane
            case .tvLive, .radioLive, .radioLiveSatellite:
                #if os(iOS)
                return .liveMediaGrid
                #else
                return .liveMediaSwimlane
                #endif
            case .history, .watchLater, .radioEpisodesForDay, .radioLatestEpisodesFromFavorites, .radioResumePlayback, .radioWatchLater, .tvEpisodesForDay, .tvLiveCenter, .tvScheduledLivestreams:
                return .mediaSwimlane
            case .favoriteShows, .radioFavoriteShows, .show:
                return .showSwimlane
            case .radioAllShows, .tvAllShows:
                return .showGrid
            case .radioShowAccess:
                #if os(iOS)
                return .showAccess
                #else
                // Not supported
                return .mediaSwimlane
                #endif
            }
        }
        
        var canOpenDetailPage: Bool {
            return layout == .mediaSwimlane || layout == .showSwimlane
        }
    }
}
