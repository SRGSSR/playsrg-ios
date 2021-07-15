//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import SRGDataProviderCombine
import SRGUserData

// MARK: View model

class MediaDetailViewModel: ObservableObject {
    struct Recommendation: Codable {
        let recommendationId: String
        let urns: [String]
    }
    
    @Published var initialMedia: SRGMedia? = nil {
        didSet {
            refresh()
            updateWatchLaterAllowedAction()
        }
    }
    
    @Published private(set) var relatedMedias: [SRGMedia] = []
    @Published private(set) var watchLaterAllowedAction: WatchLaterAction = .none
    @Published var selectedMedia: SRGMedia? {
        didSet {
            updateWatchLaterAllowedAction()
        }
    }
    
    private var mainCancellables = Set<AnyCancellable>()
    private var refreshCancellables = Set<AnyCancellable>()
    
    init() {
        NotificationCenter.default.publisher(for: .SRGPlaylistEntriesDidChange, object: SRGUserData.current?.playlists)
            .sink { [weak self] notification in
                guard let self = self,
                      let playlistUid = notification.userInfo?[SRGPlaylistUidKey] as? String, playlistUid == SRGPlaylistUid.watchLater.rawValue,
                      let entriesUids = notification.userInfo?[SRGPlaylistEntriesUidsKey] as? Set<String>, let mediaUrn = self.media?.urn, entriesUids.contains(mediaUrn) else {
                    return
                }
                self.updateWatchLaterAllowedAction()
            }
            .store(in: &mainCancellables)
    }
    
    var media: SRGMedia? {
        return selectedMedia ?? initialMedia
    }
    
    var showTitle: String? {
        if let showTitle = media?.show?.title, showTitle.lowercased() != media?.title.lowercased() {
            return showTitle
        }
        else {
            return nil
        }
    }
    
    var imageUrl: URL? {
        return media?.imageURL(for: .width, withValue: SizeForImageScale(.large).width, type: .default)
    }
    
    private func refresh() {
        guard let initialMedia = initialMedia, initialMedia.contentType != .livestream else { return }
        
        let middlewareUrl = ApplicationConfiguration.shared.middlewareURL
        let resourcePath = "api/v2/playlist/recommendation/relatedContent/" + initialMedia.urn
        let url = URL(string: resourcePath, relativeTo: middlewareUrl)!
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: Recommendation.self, decoder: JSONDecoder())
            .map { recommendation in
                return SRGDataProvider.current!.medias(withUrns: recommendation.urns)
            }
            .switchToLatest()
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.relatedMedias, on: self)
            .store(in: &refreshCancellables)
    }
    
    func toggleWatchLater() {
        guard let media = media else { return }
        WatchLaterToggleMediaMetadata(media) { added, error in
            guard error == nil else { return }
            
            let analyticsTitle = added ? AnalyticsTitle.watchLaterAdd : AnalyticsTitle.watchLaterRemove
            let labels = SRGAnalyticsHiddenEventLabels()
            labels.source = AnalyticsSource.button.rawValue
            labels.value = media.urn
            SRGAnalyticsTracker.shared.trackHiddenEvent(withName: analyticsTitle.rawValue, labels: labels)
            
            self.updateWatchLaterAllowedAction()
        }
    }
    
    private func updateWatchLaterAllowedAction() {
        guard let media = media else { return }
        watchLaterAllowedAction = WatchLaterAllowedActionForMediaMetadata(media)
    }
}
