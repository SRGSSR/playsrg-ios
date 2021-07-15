//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import SRGDataProviderCombine

// MARK: View model

class SearchResultsViewModel: ObservableObject {
    enum State {
        case loading
        case failed(error: Error)
        case mostSearched(shows: [SRGShow])
        case loaded(medias: [SRGMedia], suggestions: [SRGSearchSuggestion])
    }
    
    private var querySubject = CurrentValueSubject<String, Never>("")
    
    var query: String {
        get {
            querySubject.value
        }
        set {
            querySubject.value = newValue
        }
    }
    
    @Published private(set) var state = State.loading
    
    private typealias MediaSearchOutput = (medias: [SRGMedia], suggestions: [SRGSearchSuggestion])
    
    weak var searchController: UISearchController?
    weak var viewController: UIViewController?
    
    private var mainCancellables = Set<AnyCancellable>()
    private var refreshCancellables = Set<AnyCancellable>()
    
    private var medias: [SRGMedia] = []
    
    static let triggerIndex = 1
    
    private let trigger = Trigger()
    
    init() {
        querySubject
            .removeDuplicates()
            .debounce(for: 0.3, scheduler: RunLoop.main)
            .sink { _ in
                self.medias.removeAll()
                
                self.cancelRefresh()
                self.refresh()
            }
            .store(in: &mainCancellables)
    }
    
    func refresh() {
        guard !query.isEmpty else {
            if ApplicationConfiguration.shared.isShowsSearchHidden {
                self.state = .loaded(medias: [], suggestions: [])
            }
            else {
                SRGDataProvider.current!.mostSearchedShows(for: ApplicationConfiguration.shared.vendor, matching: .TV)
                    .receive(on: DispatchQueue.main)
                    .handleEvents(receiveRequest: { [weak self] _ in
                        guard let self = self else { return }
                        self.state = .loading
                    })
                    .sink { [weak self] completion in
                        guard let self = self else { return }
                        if case let .failure(error) = completion {
                            self.state = .failed(error: error)
                        }
                    } receiveValue: { [weak self] shows in
                        guard let self = self else { return }
                        self.state = .mostSearched(shows: shows)
                    }
                    .store(in: &refreshCancellables)
            }
            return
        }
        
        guard let publisher = mediaPublisher else { return }
        publisher
            .receive(on: DispatchQueue.main)
            .handleEvents(receiveRequest: { [weak self] _ in
                guard let self = self else { return }
                if self.medias.isEmpty {
                    self.state = .loading
                }
            })
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    guard let self = self else { return }
                    self.state = .failed(error: error)
                }
            } receiveValue: { [weak self] result in
                guard let self = self else { return }
                self.medias.append(contentsOf: result.medias)
                self.state = .loaded(medias: self.medias, suggestions: result.suggestions)
            }
            .store(in: &refreshCancellables)
    }
    
    func loadNextPage(from media: SRGMedia) {
        if media == medias.last {
            trigger.activate(for: Self.triggerIndex)
        }
    }
    
    func cancelRefresh() {
        refreshCancellables = []
    }
    
    private var searchSettings: SRGMediaSearchSettings? {
        guard !ApplicationConfiguration.shared.areSearchSettingsHidden else { return nil }
        
        let settings = SRGMediaSearchSettings()
        settings.aggregationsEnabled = false
        settings.mediaType = .video
        settings.suggestionsEnabled = true
        return settings
    }
    
    private var mediaPublisher: AnyPublisher<MediaSearchOutput, Error>? {
        return mediaSearchPublisher?
            .map { searchResult in
                return SRGDataProvider.current!.medias(withUrns: searchResult.mediaUrns, pageSize: ApplicationConfiguration.shared.pageSize)
                    .map { ($0, searchResult.suggestions ?? []) }
            }
            .switchToLatest()
            .eraseToAnyPublisher()
    }
    
    private var mediaSearchPublisher: AnyPublisher<SRGDataProvider.MediasMatchingQuery.Output, Error>? {
        let applicationConfiguration = ApplicationConfiguration.shared
        return SRGDataProvider.current!.medias(for: applicationConfiguration.vendor, matchingQuery: query, with: searchSettings, pageSize: applicationConfiguration.pageSize, paginatedBy: trigger.signal(activatedBy: Self.triggerIndex))
    }
}
