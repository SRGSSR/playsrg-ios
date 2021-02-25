//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import SRGDataProviderCombine
import SRGUserData

class MediaDetailModel: ObservableObject {
    struct Recommendation: Codable {
        let recommendationId: String
        let urns: [String]
    }
    
    private let initialMedia: SRGMedia
    
    @Published private(set) var relatedMedias: [SRGMedia] = []
    @Published var selectedMedia: SRGMedia? = nil
    @Published var isWatchedLater: Bool = false
    
    var mainCancellables = Set<AnyCancellable>()
    var refreshCancellables = Set<AnyCancellable>()
    
    init(media: SRGMedia) {
        self.initialMedia = media
        
        NotificationCenter.default.publisher(for: Notification.Name.SRGPlaylistEntriesDidChange, object: SRGUserData.current?.playlists)
            .sink { notification in
                self.updateWatchedLater()
            }
            .store(in: &mainCancellables)
        updateWatchedLater()
    }
    
    var media: SRGMedia {
        return selectedMedia ?? initialMedia
    }
    
    func refresh() {
        if initialMedia.contentType == .livestream { return }
        
        let middlewareUrl = ApplicationConfiguration.shared.middlewareURL
        
        let resourcePath = "api/v2/playlist/recommendation/relatedContent/" + initialMedia.urn
        let url = URL(string: resourcePath, relativeTo: middlewareUrl)!
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: Recommendation.self, decoder: JSONDecoder())
            .flatMap { recommendation in
                return SRGDataProvider.current!.medias(withUrns: recommendation.urns)
            }
            .map { $0.medias }
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .assign(to: \.relatedMedias, on: self)
            .store(in: &refreshCancellables)
    }
    
    func cancelRefresh() {
        refreshCancellables = []
    }
    
    func toggleWatchLater() {
        WatchLaterToggleMediaMetadata(media) { added, error in
            guard error != nil else { return }
            
            let analyticsTitle = added ? AnalyticsTitle.watchLaterAdd : AnalyticsTitle.watchLaterRemove
            let labels = SRGAnalyticsHiddenEventLabels()
            labels.source = AnalyticsSource.button.rawValue
            labels.value = self.media.urn
            SRGAnalyticsTracker.shared.trackHiddenEvent(withName: analyticsTitle.rawValue, labels: labels)
            
            self.updateWatchedLater()
        }
    }
    
    private func updateWatchedLater() {
        isWatchedLater = WatchLaterContainsMediaMetadata(media)
    }
}
