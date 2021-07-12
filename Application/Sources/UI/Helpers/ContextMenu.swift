//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import SRGDataProviderModel
import UIKit

// MARK: Context menu management

enum ContextMenu {
    static func configuration(for item: Content.Item, identifier: NSCopying? = nil, in viewController: UIViewController) -> UIContextMenuConfiguration? {
        switch item {
        case let .media(media):
            return configuration(for: media, item: item, identifier: identifier, in: viewController)
        case let .show(show):
            return configuration(for: show, item: item, identifier: identifier, in: viewController)
        default:
            return nil
        }
    }
    
    static func configuration(for item: Content.Item, at indexPath: IndexPath, in viewController: UIViewController) -> UIContextMenuConfiguration? {
        // Build an `NSIndexPath` from the `IndexPath` argument to have an equivalent identifier conforming to `NSCopying`.
        return configuration(for: item, identifier: NSIndexPath(item: indexPath.row, section: indexPath.section), in: viewController)
    }
    
    static func interactionView(in tableView: UITableView, with configuration: UIContextMenuConfiguration) -> UIView? {
        guard let indexPath = configuration.identifier as? NSIndexPath else { return nil }
        return tableView.cellForRow(at: IndexPath(row: indexPath.row, section: indexPath.section))
    }
    
    static func interactionView(in collectionView: UICollectionView, with configuration: UIContextMenuConfiguration) -> UIView? {
        guard let indexPath = configuration.identifier as? NSIndexPath else { return nil }
        return collectionView.cellForItem(at: IndexPath(row: indexPath.row, section: indexPath.section))
    }
    
    static func commitPreview(in viewController: UIViewController, animator: UIContextMenuInteractionCommitAnimating) {
        animator.preferredCommitStyle = .pop
        animator.addCompletion {
            guard let previewViewController = animator.previewViewController else { return }
            if let mediaPreviewViewController = previewViewController as? MediaPreviewViewController {
                guard let letterboxController = mediaPreviewViewController.letterboxController else { return }
                viewController.play_presentMediaPlayer(from: letterboxController, withAirPlaySuggestions: true, fromPushNotification: false, animated: true, completion: nil)
            }
            else if let navigationController = viewController.navigationController {
                navigationController.pushViewController(previewViewController, animated: true)
            }
        }
    }
}

// MARK: Sharing

private extension ContextMenu {
    private class ActivityPopoverPresentationDelegate: NSObject, UIPopoverPresentationControllerDelegate {
        func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
            return .formSheet
        }
    }
    
    private static let popoverPresentationDelegate = ActivityPopoverPresentationDelegate()
    
    private static func shareItem(_ sharingItem: SharingItem, in viewController: UIViewController) {
        let activityViewController = UIActivityViewController(sharingItem: sharingItem, source: .peekMenu, in: viewController)
        activityViewController.modalPresentationStyle = .popover
        
        let popoverPresentationController = activityViewController.popoverPresentationController
        popoverPresentationController?.sourceView = viewController.view
        popoverPresentationController?.delegate = popoverPresentationDelegate
        
        viewController.present(activityViewController, animated: true, completion: nil)
    }
}

// MARK: Media context menu

private extension ContextMenu {
    // TODO: Make item mandatory when the ObjC API is not needed anymore
    static func configuration(for media: SRGMedia, item: Content.Item?, identifier: NSCopying?, in viewController: UIViewController) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: identifier) {
            return MediaPreviewViewController(media: media)
        } actionProvider: { _ in
            return menu(for: media, item: item, in: viewController)
        }
    }
    
    private static func menu(for media: SRGMedia, item: Content.Item?, in viewController: UIViewController) -> UIMenu {
        return UIMenu(title: "", children: [
            watchLaterAction(for: media, item: item, in: viewController),
            downloadAction(for: media, item: item, in: viewController),
            sharingAction(for: media, in: viewController),
            moreEpisodesAction(for: media, in: viewController)
        ].compactMap { $0 })
    }
    
    private static func watchLaterAction(for media: SRGMedia, item: Content.Item?, in viewController: UIViewController) -> UIAction? {
        func title(for action: WatchLaterAction) -> String {
            if action == .add {
                if media.mediaType == .audio {
                    return NSLocalizedString("Listen later", comment: "Context menu action to add an audio to the later list")
                }
                else {
                    return NSLocalizedString("Watch later", comment: "Context menu action to add a video to the later list")
                }
            }
            else {
                return NSLocalizedString("Delete from \"Later\"", comment: "Context menu action to delete a media from the later list")
            }
        }
        
        func image(for action: WatchLaterAction) -> UIImage {
            return (action == .add) ? UIImage(named: "watch_later")! : UIImage(named: "watch_later_full")!
        }
        
        let action = WatchLaterAllowedActionForMediaMetadata(media)
        guard action != .none else { return nil }
        
        let menuAction = UIAction(title: title(for: action), image: image(for: action)) { _ in
            WatchLaterToggleMediaMetadata(media) { added, error in
                guard error == nil else { return }
                
                if !added, let item = item {
                    Signal.removeWatchLater(for: [item])
                }
                
                let labels = SRGAnalyticsHiddenEventLabels()
                labels.source = AnalyticsSource.peekMenu.rawValue
                labels.value = media.urn
                
                let name = added ? AnalyticsTitle.watchLaterAdd.rawValue : AnalyticsTitle.watchLaterRemove.rawValue
                SRGAnalyticsTracker.shared.trackHiddenEvent(withName: name, labels: labels)
                
                Banner.showWatchLaterAdded(added, forItemWithName: media.title, in: viewController)
            }
        }
        if action == .remove {
            menuAction.attributes = .destructive
        }
        return menuAction
    }
    
    private static func downloadAction(for media: SRGMedia, item: Content.Item?, in viewController: UIViewController) -> UIAction? {
        guard Download.canDownloadMedia(media) else { return nil}
        
        func title(for download: Download?) -> String {
            return download != nil ? NSLocalizedString("Delete from downloads", comment: "Context menu action to delete a media from the downloads") : NSLocalizedString("Add to downloads", comment: "Context menu action to add a media to the downloads")
        }
        
        func image(for download: Download?) -> UIImage {
            return download != nil ? UIImage(named: "downloadable_stop")! : UIImage(named: "downloadable")!
        }
        
        let download = Download(for: media)
        let menuAction = UIAction(title: title(for: download), image: image(for: download)) { _ in
            if let download = download {
                Download.removeDownload(download)
            }
            else {
                Download.add(for: media)
            }
            
            let labels = SRGAnalyticsHiddenEventLabels()
            labels.source = AnalyticsSource.peekMenu.rawValue
            labels.value = media.urn
            
            let name = (download == nil) ? AnalyticsTitle.downloadAdd.rawValue : AnalyticsTitle.downloadRemove.rawValue
            SRGAnalyticsTracker.shared.trackHiddenEvent(withName: name, labels: labels)
            
            Banner.showDownload(download == nil, forItemWithName: media.title, in: viewController)
        }
        if download != nil {
            menuAction.attributes = .destructive
        }
        return menuAction
    }
    
    private static func sharingAction(for media: SRGMedia, in viewController: UIViewController) -> UIAction? {
        guard let sharingItem = SharingItem(for: media, at: CMTime.zero) else { return nil }
        return UIAction(title: NSLocalizedString("Share", comment: "Context menu action to share a media"),
                                  image: UIImage(named: "share")!) { _ in
            shareItem(sharingItem, in: viewController)
        }
    }
    
    private static func moreEpisodesAction(for media: SRGMedia, in viewController: UIViewController) -> UIAction? {
        guard !ApplicationConfiguration.shared.areShowsUnavailable,
              let show = media.show,
              let navigationController = viewController.navigationController else { return nil }
        return UIAction(title: NSLocalizedString("More episodes", comment: "Context menu action to open more episodes associated with a media"),
                        image: UIImage(named: "episodes")) { _ in
            let showViewController = SectionViewController.showViewController(for: show)
            navigationController.pushViewController(showViewController, animated: true)
        }
    }
}

// MARK: Show context menu

private extension ContextMenu {
    // TODO: Make item mandatory when the ObjC API is not needed anymore
    static func configuration(for show: SRGShow, item: Content.Item?, identifier: NSCopying?, in viewController: UIViewController) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: identifier) {
            return SectionViewController.showViewController(for: show)
        } actionProvider: { _ in
            return menu(for: show, item: item, in: viewController)
        }
    }
    
    private static func menu(for show: SRGShow, item: Content.Item?, in viewController: UIViewController) -> UIMenu {
        return UIMenu(title: "", children: [
            favoriteAction(for: show, item: item, in: viewController),
            sharingAction(for: show, in: viewController)
        ].compactMap { $0 })
    }
    
    private static func favoriteAction(for show: SRGShow, item: Content.Item?, in viewController: UIViewController) -> UIAction? {
        func title(isFavorite: Bool) -> String {
            return isFavorite ? NSLocalizedString("Delete from favorites", comment: "Context menu action to delete a show from favorites") : NSLocalizedString("Add to favorites", comment: "Context menu action to add a show to favorites")
        }
        
        func image(isFavorite: Bool) -> UIImage {
            return isFavorite ? UIImage(named: "favorite_full")! : UIImage(named: "favorite")!
        }
        
        let isFavorite = FavoritesContainsShow(show)
        let menuAction = UIAction(title: title(isFavorite: isFavorite), image: image(isFavorite: isFavorite)) { _ in
            FavoritesToggleShow(show)
            
            if isFavorite, let item = item {
                Signal.removeFavorite(for: [item])
            }
            
            let labels = SRGAnalyticsHiddenEventLabels()
            labels.source = AnalyticsSource.peekMenu.rawValue
            labels.value = show.urn
            
            let name = !isFavorite ? AnalyticsTitle.favoriteAdd.rawValue : AnalyticsTitle.favoriteRemove.rawValue
            SRGAnalyticsTracker.shared.trackHiddenEvent(withName: name, labels: labels)
            
            Banner.showFavorite(!isFavorite, forItemWithName: show.title, in: viewController)
        }
        if isFavorite {
            menuAction.attributes = .destructive
        }
        return menuAction
    }
    
    private static func sharingAction(for show: SRGShow, in viewController: UIViewController) -> UIAction? {
        guard let sharingItem = SharingItem(for: show) else { return nil }
        return UIAction(title: NSLocalizedString("Share", comment: "Context menu action to share a show"),
                        image: UIImage(named: "share")!) { _ in
            shareItem(sharingItem, in: viewController)
        }
    }
}

// MARK: Objective-C API

@objc final class ContextMenuObjC: NSObject {
    @objc static func configuration(for object: AnyObject, at indexPath: NSIndexPath, in viewController: UIViewController) -> UIContextMenuConfiguration? {
        switch object {
        case let media as SRGMedia:
            return ContextMenu.configuration(for: media, item: nil, identifier: indexPath, in: viewController)
        case let show as SRGShow:
            return ContextMenu.configuration(for: show, item: nil, identifier: indexPath, in: viewController)
        case let download as Download:
            if let media = download.media {
                return ContextMenu.configuration(for: media, item: nil, identifier: indexPath, in: viewController)
            }
            else {
                return nil
            }
        default:
            return nil
        }
    }
    
    @objc static func interactionView(inTableView tableView: UITableView, with configuration: UIContextMenuConfiguration) -> UIView? {
        return ContextMenu.interactionView(in: tableView, with: configuration)
    }
    
    @objc static func interactionView(inCollectionView collectionView: UICollectionView, with configuration: UIContextMenuConfiguration) -> UIView? {
        return ContextMenu.interactionView(in: collectionView, with: configuration)
    }
    
    @objc static func commitPreview(in viewController: UIViewController, animator: UIContextMenuInteractionCommitAnimating) {
        ContextMenu.commitPreview(in: viewController, animator: animator)
    }
}
