//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import Combine
import SRGDataProviderModel

// MARK: View model

final class ShowHeaderViewModel: ObservableObject {
    var show: SRGShow? {
        didSet {
            updatePublishers()
        }
    }
    
    @Published private(set) var isFavorite: Bool = false
    @Published private(set) var isSubscribed: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    var title: String? {
        return show?.title
    }
    
    var lead: String? {
        return show?.lead
    }
    
    var broadcastInformation: String? {
        return show?.broadcastInformation?.message
    }
    
    var imageUrl: URL? {
        return show?.imageUrl(for: .large)
    }
    
    var favoriteIcon: String {
        return isFavorite ? "favorite_full" : "favorite"
    }
    
    var favoriteLabel: String {
        if isFavorite {
            return NSLocalizedString("Favorites", comment: "Label displayed in the show view when a show has been favorited")
        }
        else {
            return NSLocalizedString("Add to favorites", comment: "Label displayed in the show view when a show can be favorited")
        }
    }
    
    var favoriteAccessibilityLabel: String {
        if isFavorite {
            return PlaySRGAccessibilityLocalizedString("Delete from favorites", comment: "Favorite label in the show view when a show has been favorited")
        }
        else {
            return PlaySRGAccessibilityLocalizedString("Add to favorites", comment: "Favorite label in the show view when a show can be favorited")
        }
    }
    
    #if os(iOS)
    var subscriptionIcon: String {
        if isPushServiceEnabled {
            return isSubscribed ? "subscription_full" : "subscription"
        }
        else {
            return "subscription_disabled"
        }
    }
    
    var subscriptionLabel: String {
        if isPushServiceEnabled && isSubscribed {
            return NSLocalizedString("Notified", comment: "Subscription label when notification enabled in the show view")
        }
        else {
            return NSLocalizedString("Notify me", comment: "Subscription label to be notified in the show view")
        }
    }
    
    var subscriptionAccessibilityLabel: String {
        if isPushServiceEnabled && isSubscribed {
            return PlaySRGAccessibilityLocalizedString("Disable notifications for show", comment: "Show unsubscription label")
        }
        else {
            return PlaySRGAccessibilityLocalizedString("Enable notifications for show", comment: "Show subscription label")
        }
    }
    
    private var isPushServiceEnabled: Bool {
        if let pushService = PushService.shared {
            return pushService.isEnabled
        }
        else {
            return false
        }
    }
    #endif
    
    func toggleFavorite() {
        guard let show = show else { return }
        FavoritesToggleShow(show)
        updateData()
        
        let labels = SRGAnalyticsHiddenEventLabels()
        labels.source = AnalyticsSource.button.rawValue
        labels.value = show.urn
        
        let name = isFavorite ? AnalyticsTitle.favoriteAdd.rawValue : AnalyticsTitle.favoriteRemove.rawValue
        SRGAnalyticsTracker.shared.trackHiddenEvent(withName: name, labels: labels)
        
        #if os(iOS)
        Banner.showFavorite(isFavorite, forItemWithName: show.title)
        #endif
    }
    
    #if os(iOS)
    func toggleSubscription() {
        guard let show = show, FavoritesToggleSubscriptionForShow(show) else { return }
        updateData()
        
        let labels = SRGAnalyticsHiddenEventLabels()
        labels.source = AnalyticsSource.button.rawValue
        labels.value = show.urn
        
        let name = isSubscribed ? AnalyticsTitle.subscriptionAdd.rawValue : AnalyticsTitle.subscriptionRemove.rawValue
        SRGAnalyticsTracker.shared.trackHiddenEvent(withName: name, labels: labels)
        
        Banner.showSubscription(isSubscribed, forItemWithName: show.title)
    }
    #endif
    
    private func updatePublishers() {
        cancellables = []
        
        Publishers.Merge(Signal.favoritesUpdate(), Signal.wokenUp())
            .sink { [weak self] _ in
                self?.updateData()
            }
            .store(in: &cancellables)
        updateData()
    }
    
    private func updateData() {
        if let show = show {
            isFavorite = FavoritesContainsShow(show)
            isSubscribed = FavoritesIsSubscribedToShow(show)
        }
        else {
            isFavorite = false
            isSubscribed = false
        }
    }
}
