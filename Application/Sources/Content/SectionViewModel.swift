//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import FXReachability
import SRGDataProviderCombine

// MARK: View model

class SectionViewModel: ObservableObject {
    let section: Content.Section
    
    @Published private(set) var state: State = .loading
    
    private var selectedItems = Set<Content.Item>()
    private var trigger = Trigger()
    private var cancellables = Set<AnyCancellable>()
    
    var title: String? {
        return section.properties.displaysTitle ? section.properties.title : nil
    }
    
    var numberOfSelectedItem: Int {
        return selectedItems.count
    }
    
    init(section: Content.Section, filter: SectionFiltering?) {
        self.section = section
        
        let rowSection = SectionViewModel.Section(section)
        Publishers.PublishAndRepeat(onOutputFrom: trigger.signal(activatedBy: TriggerId.reload)) { [trigger] in
            return Publishers.CombineLatest(
                rowSection.properties.publisher(pageSize: ApplicationConfiguration.shared.detailPageSize,
                                                paginatedBy: trigger.signal(activatedBy: TriggerId.loadMore),
                                                filter: filter)
                    .scan([]) { $0 + $1 },
                rowSection.properties.removalPublisher()
                    .prepend(Just([]))
                    .setFailureType(to: Error.self)
            )
            .map { items, removedItems in
                return items.filter { !removedItems.contains($0) }
            }
            .map { items in
                let headerItem = rowSection.viewModelProperties.headerItem(from: items)
                let rowItems = removeDuplicates(in: rowSection.viewModelProperties.rowItems(from: items))
                return State.loaded(headerItem: headerItem, row: Row(section: rowSection, items: rowItems))
            }
            .catch { error in
                return Just(State.failed(error: error))
            }
        }
        .receive(on: DispatchQueue.main)
        .assign(to: &$state)
        
        Signal.wokenUp()
            .sink { [weak self] in
                self?.reload()
            }
            .store(in: &cancellables)
    }
    
    func loadMore() {
        trigger.activate(for: TriggerId.loadMore)
    }
    
    func reload(deep: Bool = false) {
        if deep || state.isEmpty {
            trigger.activate(for: TriggerId.reload)
        }
    }
    
    func toggleSelection(for item: Content.Item) {
        if selectedItems.contains(item) {
            selectedItems.remove(item)
        }
        else {
            selectedItems.insert(item)
        }
    }
    
    func hasSelected(_ item: Content.Item) -> Bool {
        return selectedItems.contains(item)
    }
    
    func clearSelection() {
        selectedItems.removeAll()
    }
    
    func deleteSelection() {
        section.properties.remove(Array(selectedItems))
        selectedItems.removeAll()
    }
}

// MARK: Types

extension SectionViewModel {
    struct Section: Hashable {
        let wrappedValue: Content.Section
        
        init(_ wrappedValue: Content.Section) {
            self.wrappedValue = wrappedValue
        }
        
        var properties: SectionProperties {
            return wrappedValue.properties
        }
        
        var viewModelProperties: SectionViewModelProperties {
            switch wrappedValue {
            case let .content(section):
                return ContentSectionProperties(contentSection: section)
            case let .configured(section):
                return ConfiguredSectionProperties(configuredSection: section)
            }
        }
    }
    
    enum HeaderItem {
        case item(Content.Item)
        case show(SRGShow)
    }
    
    typealias Item = Content.Item
    typealias Row = CollectionRow<Section, Item>
    
    enum State {
        case loading
        case failed(error: Error)
        case loaded(headerItem: HeaderItem?, row: Row)
        
        var isEmpty: Bool {
            if case let .loaded(headerItem: _, row: row) = self {
                return row.isEmpty
            }
            else {
                return true
            }
        }
        
        var headerItem: HeaderItem? {
            if case let .loaded(headerItem: headerItem, row: _) = self {
                return headerItem
            }
            else {
                return nil
            }
        }
    }
    
    enum SectionLayout: Hashable {
        case liveMediaGrid
        case mediaGrid
        case showGrid
        case topicGrid
    }
    
    enum TriggerId {
        case loadMore
        case reload
    }
}

// MARK: Properties

protocol SectionViewModelProperties {
    var layout: SectionViewModel.SectionLayout { get }
    
    func headerItem(from items: [SectionViewModel.Item]) -> SectionViewModel.HeaderItem?
    func rowItems(from items: [SectionViewModel.Item]) -> [SectionViewModel.Item]
}

private extension SectionViewModel {
    struct ContentSectionProperties: SectionViewModelProperties {
        let contentSection: SRGContentSection
        
        var layout: SectionViewModel.SectionLayout {
            switch contentSection.type {
            case .medias, .showAndMedias:
                return .mediaGrid
            case .shows:
                return .showGrid
            case .predefined:
                switch contentSection.presentation.type {
                case .hero, .mediaHighlight, .mediaHighlightSwimlane, .resumePlayback, .watchLater, .personalizedProgram:
                    return .mediaGrid
                case .showHighlight, .favoriteShows:
                    return .showGrid
                case .topicSelector:
                    return .topicGrid
                case .livestreams:
                    return .liveMediaGrid
                case .swimlane, .grid:
                    return (contentSection.type == .shows) ? .showGrid : .mediaGrid
                case .none, .showAccess:
                    return .mediaGrid
                }
            case .none:
                return .mediaGrid
            }
        }
        
        func headerItem(from items: [SectionViewModel.Item]) -> SectionViewModel.HeaderItem? {
            if contentSection.type == .showAndMedias, let firstItem = items.first, case .show = firstItem {
                return .item(firstItem)
            }
            else {
                return nil
            }
        }
        
        func rowItems(from items: [SectionViewModel.Item]) -> [SectionViewModel.Item] {
            if contentSection.type == .showAndMedias, case .show = items.first {
                return Array(items.suffix(from: 1))
            }
            else {
                return items
            }
        }
    }
    
    struct ConfiguredSectionProperties: SectionViewModelProperties {
        let configuredSection: ConfiguredSection
        
        var layout: SectionViewModel.SectionLayout {
            switch configuredSection {
            case .show, .history, .watchLater, .radioEpisodesForDay, .radioLatest, .radioLatestEpisodes, .radioLatestEpisodesFromFavorites, .radioLatestVideos, .radioMostPopular, .radioResumePlayback, .radioWatchLater, .tvEpisodesForDay, .tvLiveCenter, .tvScheduledLivestreams:
                return .mediaGrid
            case .tvLive, .radioLive, .radioLiveSatellite:
                return .liveMediaGrid
            case .favoriteShows, .radioFavoriteShows, .radioAllShows, .tvAllShows:
                return .showGrid
            case .radioShowAccess:
                return .mediaGrid
            }
        }
        
        func headerItem(from items: [SectionViewModel.Item]) -> SectionViewModel.HeaderItem? {
            switch configuredSection {
            case let .show(show):
                return .show(show)
            default:
                return nil
            }
        }
        
        func rowItems(from items: [SectionViewModel.Item]) -> [SectionViewModel.Item] {
            return items
        }
    }
}
