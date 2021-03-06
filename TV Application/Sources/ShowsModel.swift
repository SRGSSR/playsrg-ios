//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import SRGDataProviderCombine

class ShowsModel: ObservableObject {
    enum State {
        case loading
        case failed(error: Error)
        case loaded(alphabeticalShows: [(character: Character, shows: [SRGShow])])
    }
    
    @Published private(set) var state = State.loading
    
    private var cancellables = Set<AnyCancellable>()
    private var alphabeticalShows: [(character: Character, shows: [SRGShow])] = []
    
    func refresh() {
        guard alphabeticalShows.isEmpty else { return }
        loadPage()
    }
    
    func loadPage() {
        SRGDataProvider.current!.tvShows(for: ApplicationConfiguration.shared.vendor, pageSize: SRGDataProviderUnlimitedPageSize)
            .receive(on: DispatchQueue.main)
            .handleEvents(receiveRequest:  { _ in
                if self.alphabeticalShows.isEmpty {
                    self.state = .loading
                }
            })
            .sink(receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    self.state = .failed(error: error)
                }
            }, receiveValue: { result in
                self.alphabeticalShows = Dictionary(grouping: result.shows) { show in
                    // Remove accents / diacritics and extract the first character (for wide chars / emoji support)
                    guard let character = show.title.folding(options: .diacriticInsensitive, locale: .current).uppercased().first else { return "#" }
                    return !character.isLetter ? "#" : character
                }
                .map { (character: $0, shows: $1) }
                .sorted { left, right in
                    left.character < right.character
                }
                self.state = .loaded(alphabeticalShows: self.alphabeticalShows)
            })
            .store(in: &cancellables)
    }
    
    func cancelRefresh() {
        cancellables = []
    }
}
