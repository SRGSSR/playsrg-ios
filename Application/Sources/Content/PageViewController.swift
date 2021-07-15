//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import Combine
import SRGAppearanceSwift
import SwiftUI
import UIKit

// MARK: View controller

final class PageViewController: UIViewController {
    private let model: PageViewModel
    
    private var cancellables = Set<AnyCancellable>()

    private var dataSource: UICollectionViewDiffableDataSource<PageViewModel.Section, PageViewModel.Item>!
    
    private weak var collectionView: UICollectionView!
    private weak var emptyView: HostView<EmptyView>!
    
    #if os(iOS)
    private weak var refreshControl: UIRefreshControl!
    #endif
    
    private var refreshTriggered = false
    
    private var globalHeaderTitle: String? {
        #if os(tvOS)
        return tabBarController == nil ? model.title : nil
        #else
        return nil
        #endif
    }
    
    private static func snapshot(from state: PageViewModel.State) -> NSDiffableDataSourceSnapshot<PageViewModel.Section, PageViewModel.Item> {
        var snapshot = NSDiffableDataSourceSnapshot<PageViewModel.Section, PageViewModel.Item>()
        if case let .loaded(rows: rows) = state {
            for row in rows {
                snapshot.appendSections([row.section])
                snapshot.appendItems(row.items, toSection: row.section)
            }
        }
        return snapshot
    }
    
    init(id: PageViewModel.Id) {
        model = PageViewModel(id: id)
        super.init(nibName: nil, bundle: nil)
        title = model.title
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc var radioChannel: RadioChannel? {
        if case let .audio(channel: channel) = model.id {
            return channel
        }
        else {
            return nil
        }
    }
    
    override func loadView() {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .srgGray16
        
        let collectionView = CollectionView(frame: .zero, collectionViewLayout: layout())
        collectionView.delegate = self
        collectionView.backgroundColor = .clear
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        self.collectionView = collectionView
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        let emptyView = HostView<EmptyView>(frame: .zero)
        collectionView.backgroundView = emptyView
        self.emptyView = emptyView
        
        #if os(tvOS)
        self.tabBarObservedScrollView = collectionView
        #else
        let refreshControl = RefreshControl()
        refreshControl.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        collectionView.insertSubview(refreshControl, at: 0)
        self.refreshControl = refreshControl
        
        if model.id.supportsCastButton, let navigationBar = navigationController?.navigationBar {
            navigationItem.rightBarButtonItem = GoogleCastBarButtonItem(for: navigationBar)
        }
        #endif
        
        self.view = view
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let cellRegistration = UICollectionView.CellRegistration<HostCollectionViewCell<ItemCell>, PageViewModel.Item> { [model] cell, _, item in
            cell.content = ItemCell(item: item, id: model.id)
        }
        
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }
        
        let globalHeaderViewRegistration = UICollectionView.SupplementaryRegistration<HostSupplementaryView<TitleView>>(elementKind: Header.global.rawValue) { [weak self] view, _, _ in
            guard let self = self else { return }
            view.content = TitleView(text: self.globalHeaderTitle)
        }
        
        let sectionHeaderViewRegistration = UICollectionView.SupplementaryRegistration<HostSupplementaryView<SectionHeaderView>>(elementKind: UICollectionView.elementKindSectionHeader) { [weak self] view, _, indexPath in
            guard let self = self else { return }
            let snapshot = self.dataSource.snapshot()
            let section = snapshot.sectionIdentifiers[indexPath.section]
            view.content = SectionHeaderView(section: section, pageId: self.model.id)
        }
        
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            if kind == Header.global.rawValue {
                return collectionView.dequeueConfiguredReusableSupplementary(using: globalHeaderViewRegistration, for: indexPath)
            }
            else {
                return collectionView.dequeueConfiguredReusableSupplementary(using: sectionHeaderViewRegistration, for: indexPath)
            }
        }
        
        model.$state
            .sink { [weak self] state in
                self?.reloadData(for: state)
            }
            .store(in: &cancellables)
        
        #if os(iOS)
        model.$serviceStatus
            .sink { [weak self] status in
                if let self = self, case let .bad(message) = status {
                    Banner.show(with: .error, message: message.text, image: nil, sticky: true, in: self)
                }
            }
            .store(in: &cancellables)
        #endif
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        model.reload()
    }
    
    #if os(iOS)
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return Self.play_supportedInterfaceOrientations
    }
    #endif
    
    func reloadData(for state: PageViewModel.State) {
        switch state {
        case .loading:
            emptyView.content = EmptyView(state: .loading)
        case let .failed(error: error):
            emptyView.content = EmptyView(state: .failed(error: error))
        case let .loaded(rows: rows):
            emptyView.content = rows.isEmpty ? EmptyView(state: .empty) : nil
        }
        
        DispatchQueue.global(qos: .userInteractive).async {
            // Can be triggered on a background thread. Layout is updated on the main thread.
            self.dataSource.apply(Self.snapshot(from: state)) {
                #if os(iOS)
                // Avoid stopping scrolling
                // See http://stackoverflow.com/a/31681037/760435
                if self.refreshControl.isRefreshing {
                    self.refreshControl.endRefreshing()
                }
                #endif
            }
        }
    }
    
    #if os(iOS)
    @objc func pullToRefresh(_ refreshControl: RefreshControl) {
        if refreshControl.isRefreshing {
            refreshControl.endRefreshing()
        }
        refreshTriggered = true
    }
    #endif
}

// MARK: Types

private extension PageViewController {
    enum Header: String {
        case global
    }
    
    #if os(iOS)
    private typealias CollectionView = DampedCollectionView
    #else
    private typealias CollectionView = UICollectionView
    #endif
}

// MARK: Objective-C API

extension PageViewController {
    @objc static func videosViewController() -> UIViewController {
        return PageViewController(id: .video)
    }
    
    @objc static func audiosViewController(forRadioChannel channel: RadioChannel) -> UIViewController {
        return PageViewController(id: .audio(channel: channel))
    }
    
    @objc static func liveViewController() -> UIViewController {
        return PageViewController(id: .live)
    }
    
    @objc static func topicViewController(for topic: SRGTopic) -> UIViewController {
        return PageViewController(id: .topic(topic: topic))
    }
}

// MARK: Protocols

extension PageViewController: ContentInsets {
    var play_contentScrollViews: [UIScrollView]? {
        return collectionView != nil ? [collectionView] : nil
    }
    
    var play_paddingContentInsets: UIEdgeInsets {
        return UIEdgeInsets(top: Self.layoutVerticalMargin, left: 0, bottom: Self.layoutVerticalMargin, right: 0)
    }
}

extension PageViewController: UICollectionViewDelegate {
    #if os(iOS)
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let snapshot = dataSource.snapshot()
        let section = snapshot.sectionIdentifiers[indexPath.section]
        let item = snapshot.itemIdentifiers(inSection: section)[indexPath.row]
        
        switch item.wrappedValue {
        case let .item(wrappedItem):
            switch wrappedItem {
            case let .media(media):
                play_presentMediaPlayer(with: media, position: nil, airPlaySuggestions: true, fromPushNotification: false, animated: true, completion: nil)
            case let .show(show):
                if let navigationController = navigationController {
                    let showViewController = SectionViewController.showViewController(for: show)
                    navigationController.pushViewController(showViewController, animated: true)
                }
            case let .topic(topic):
                if let navigationController = navigationController {
                    let pageViewController = PageViewController(id: .topic(topic: topic))
                    navigationController.pushViewController(pageViewController, animated: true)
                }
            default:
                ()
            }
        case .more:
            if let navigationController = navigationController {
                let sectionViewController = SectionViewController(section: section.wrappedValue, filter: model.id)
                navigationController.pushViewController(sectionViewController, animated: true)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let snapshot = dataSource.snapshot()
        let section = snapshot.sectionIdentifiers[indexPath.section]
        let item = snapshot.itemIdentifiers(inSection: section)[indexPath.row]
        
        switch item.wrappedValue {
        case let .item(wrappedItem):
            return ContextMenu.configuration(for: wrappedItem, at: indexPath, in: self)
        default:
            return nil
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        ContextMenu.commitPreview(in: self, animator: animator)
    }
    
    func collectionView(_ collectionView: UICollectionView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        return preview(for: configuration, in: collectionView)
    }
    
    func collectionView(_ collectionView: UICollectionView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        return preview(for: configuration, in: collectionView)
    }
    
    private func preview(for configuration: UIContextMenuConfiguration, in collectionView: UICollectionView) -> UITargetedPreview? {
        guard let interactionView = ContextMenu.interactionView(in: collectionView, with: configuration) else { return nil }
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = view.backgroundColor
        return UITargetedPreview(view: interactionView, parameters: parameters)
    }
    #endif
    
    #if os(tvOS)
    func collectionView(_ collectionView: UICollectionView, canFocusItemAt indexPath: IndexPath) -> Bool {
        return false
    }
    #endif
}

extension PageViewController: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // Avoid the collection jumping when pulling to refresh. Only mark the refresh as being triggered.
        if refreshTriggered {
            model.reload(deep: true)
            refreshTriggered = false
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.contentSize.height > 0 else { return }
        
        let numberOfScreens = 4
        if scrollView.contentOffset.y > scrollView.contentSize.height - CGFloat(numberOfScreens) * scrollView.frame.height {
            model.loadMore()
        }
    }
}

#if os(iOS)

extension PageViewController: PlayApplicationNavigation {
    func open(_ applicationSectionInfo: ApplicationSectionInfo) -> Bool {
        guard radioChannel === applicationSectionInfo.radioChannel || radioChannel == applicationSectionInfo.radioChannel else { return false }
        
        switch applicationSectionInfo.applicationSection {
        case .showByDate:
            let date = applicationSectionInfo.options?[ApplicationSectionOptionKey.showByDateDateKey] as? Date
            if let navigationController = navigationController {
                let calendarViewController = CalendarViewController(radioChannel: applicationSectionInfo.radioChannel, date: date)
                navigationController.pushViewController(calendarViewController, animated: false)
            }
            return true
        case .showAZ:
            let index = applicationSectionInfo.options?[ApplicationSectionOptionKey.showAZIndexKey] as? String
            if let navigationController = navigationController {
                let showsViewController = ShowsViewController(radioChannel: applicationSectionInfo.radioChannel, alphabeticalIndex: index)
                navigationController.pushViewController(showsViewController, animated: false)
            }
            return true
        default:
            return applicationSectionInfo.applicationSection == .overview
        }
    }
}

#endif

extension PageViewController: SRGAnalyticsViewTracking {
    var srg_pageViewTitle: String {
        switch model.id {
        case .video, .audio, .live:
            return AnalyticsPageTitle.home.rawValue
        case let .topic(topic: topic):
            return topic.title
        }
    }
    
    var srg_pageViewLevels: [String]? {
        switch model.id {
        case .video:
            return [AnalyticsPageLevel.play.rawValue, AnalyticsPageLevel.video.rawValue]
        case let .audio(channel: channel):
            return [AnalyticsPageLevel.play.rawValue, AnalyticsPageLevel.audio.rawValue, channel.name]
        case .live:
            return [AnalyticsPageLevel.play.rawValue, AnalyticsPageLevel.live.rawValue]
        case .topic:
            return [AnalyticsPageLevel.play.rawValue, AnalyticsPageLevel.video.rawValue, AnalyticsPageLevel.topic.rawValue]
        }
    }
}

#if os(iOS)

extension PageViewController: ShowAccessCellActions {
    func openShowAZ() {
        if let navigationController = navigationController {
            let showsViewController = ShowsViewController(radioChannel: radioChannel, alphabeticalIndex: nil)
            navigationController.pushViewController(showsViewController, animated: true)
        }
    }
    
    func openShowByDate() {
        if let navigationController = navigationController {
            let programGuideViewController = ProgramGuideViewController()
            navigationController.pushViewController(programGuideViewController, animated: true)
        }
    }
}

extension PageViewController: SectionHeaderViewAction {
    fileprivate func openSection(sender: Any?, event: OpenSectionEvent?) {
        if let event = event, let navigationController = navigationController {
            let sectionViewController = SectionViewController(section: event.section.wrappedValue, filter: model.id)
            navigationController.pushViewController(sectionViewController, animated: true)
        }
    }
}

extension PageViewController: TabBarActionable {
    func performActiveTabAction(animated: Bool) {
        collectionView.play_scrollToTop(animated: animated)
    }
}

#endif

// MARK: Layout

private extension PageViewController {
    private static let itemSpacing: CGFloat = constant(iOS: 8, tvOS: 40)
    private static let layoutVerticalMargin: CGFloat = constant(iOS: 8, tvOS: 0)
    
    private func layoutConfiguration() -> UICollectionViewCompositionalLayoutConfiguration {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.interSectionSpacing = constant(iOS: 35, tvOS: 70)
        configuration.contentInsetsReference = constant(iOS: .automatic, tvOS: .layoutMargins)
        
        let headerSize = TitleViewSize.recommended(text: globalHeaderTitle)
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: Header.global.rawValue, alignment: .topLeading)
        configuration.boundarySupplementaryItems = [header]
        
        return configuration
    }
    
    private func layout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout(sectionProvider: { [weak self] sectionIndex, layoutEnvironment in
            let layoutWidth = layoutEnvironment.container.effectiveContentSize.width
            
            func sectionSupplementaryItems(for section: PageViewModel.Section, index: Int) -> [NSCollectionLayoutBoundarySupplementaryItem] {
                let headerSize = SectionHeaderView.size(section: section, layoutWidth: layoutWidth)
                let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .topLeading)
                return [header]
            }
            
            func layoutSection(for section: PageViewModel.Section) -> NSCollectionLayoutSection {
                let horizontalSizeClass = layoutEnvironment.traitCollection.horizontalSizeClass
                
                switch section.viewModelProperties.layout {
                case .hero:
                    let layoutSection = NSCollectionLayoutSection.horizontal(layoutWidth: layoutWidth, spacing: Self.itemSpacing) { layoutWidth, _ in
                        return FeaturedContentCellSize.hero(layoutWidth: layoutWidth, horizontalSizeClass: horizontalSizeClass)
                    }
                    layoutSection.orthogonalScrollingBehavior = .groupPaging
                    return layoutSection
                case .highlight:
                    return NSCollectionLayoutSection.horizontal(layoutWidth: layoutWidth, spacing: Self.itemSpacing) { layoutWidth, _ in
                        return FeaturedContentCellSize.highlight(layoutWidth: layoutWidth, horizontalSizeClass: horizontalSizeClass)
                    }
                case .highlightSwimlane:
                    let layoutSection = NSCollectionLayoutSection.horizontal(layoutWidth: layoutWidth, spacing: Self.itemSpacing) { layoutWidth, _ in
                        return FeaturedContentCellSize.highlight(layoutWidth: layoutWidth, horizontalSizeClass: horizontalSizeClass)
                    }
                    layoutSection.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary
                    return layoutSection
                case .mediaSwimlane:
                    let layoutSection = NSCollectionLayoutSection.horizontal(layoutWidth: layoutWidth, spacing: Self.itemSpacing) { _, _ in
                        return MediaCellSize.swimlane()
                    }
                    layoutSection.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary
                    return layoutSection
                case .liveMediaSwimlane:
                    let layoutSection = NSCollectionLayoutSection.horizontal(layoutWidth: layoutWidth, spacing: Self.itemSpacing) { _, _ in
                        return LiveMediaCellSize.swimlane()
                    }
                    layoutSection.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary
                    return layoutSection
                case .showSwimlane:
                    let layoutSection = NSCollectionLayoutSection.horizontal(layoutWidth: layoutWidth, spacing: Self.itemSpacing) { _, _ in
                        return ShowCellSize.swimlane()
                    }
                    layoutSection.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary
                    return layoutSection
                case .topicSelector:
                    let layoutSection = NSCollectionLayoutSection.horizontal(layoutWidth: layoutWidth, spacing: Self.itemSpacing) { _, _ in
                        return TopicCellSize.swimlane()
                    }
                    layoutSection.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary
                    return layoutSection
                case .mediaGrid:
                    if horizontalSizeClass == .compact {
                        return NSCollectionLayoutSection.horizontal(layoutWidth: layoutWidth, spacing: Self.itemSpacing) { _, _ in
                            return MediaCellSize.fullWidth()
                        }
                    }
                    else {
                        return NSCollectionLayoutSection.grid(layoutWidth: layoutWidth, spacing: Self.itemSpacing) { layoutWidth, spacing in
                            return MediaCellSize.grid(layoutWidth: layoutWidth, spacing: Self.itemSpacing, minimumNumberOfColumns: 1)
                        }
                    }
                case .liveMediaGrid:
                    return NSCollectionLayoutSection.grid(layoutWidth: layoutWidth, spacing: Self.itemSpacing) { layoutWidth, spacing in
                        return LiveMediaCellSize.grid(layoutWidth: layoutWidth, spacing: Self.itemSpacing, minimumNumberOfColumns: 2)
                    }
                case .showGrid:
                    return NSCollectionLayoutSection.grid(layoutWidth: layoutWidth, spacing: Self.itemSpacing) { layoutWidth, spacing in
                        return ShowCellSize.grid(layoutWidth: layoutWidth, spacing: Self.itemSpacing, minimumNumberOfColumns: 2)
                    }
                #if os(iOS)
                case .showAccess:
                    return NSCollectionLayoutSection.horizontal(layoutWidth: layoutWidth, spacing: Self.itemSpacing) { layoutWidth, _ in
                        return ShowAccessCellSize.fullWidth(layoutWidth: layoutWidth)
                    }
                #endif
                }
            }
            
            guard let self = self else { return nil }
            
            let snapshot = self.dataSource.snapshot()
            let section = snapshot.sectionIdentifiers[sectionIndex]
            
            let layoutSection = layoutSection(for: section)
            layoutSection.boundarySupplementaryItems = sectionSupplementaryItems(for: section, index: sectionIndex)
            return layoutSection
        }, configuration: layoutConfiguration())
    }
}

// MARK: Cells

private extension PageViewController {
    struct MediaCell: View {
        let media: SRGMedia?
        let section: PageViewModel.Section
        
        var body: some View {
            switch section.viewModelProperties.layout {
            case .hero:
                FeaturedContentCell(media: media, label: section.properties.label, layout: .hero)
            case .highlight, .highlightSwimlane:
                FeaturedContentCell(media: media, label: section.properties.label, layout: .highlight)
            case .liveMediaSwimlane, .liveMediaGrid:
                LiveMediaCell(media: media)
            case .mediaGrid:
                PlaySRG.MediaCell(media: media, style: .show)
            default:
                PlaySRG.MediaCell(media: media, style: .show, layout: .vertical)
            }
        }
    }
    
    struct ShowCell: View {
        let show: SRGShow?
        let section: PageViewModel.Section
        
        var body: some View {
            switch section.viewModelProperties.layout {
            case .hero:
                FeaturedContentCell(show: show, label: section.properties.label, layout: .hero)
            case .highlight:
                FeaturedContentCell(show: show, label: section.properties.label, layout: .highlight)
            default:
                PlaySRG.ShowCell(show: show)
            }
        }
    }
    
    struct ItemCell: View {
        let item: PageViewModel.Item
        let id: PageViewModel.Id
        
        var body: some View {
            switch item.wrappedValue {
            case let .item(wrappedItem):
                switch wrappedItem {
                case .mediaPlaceholder:
                    MediaCell(media: nil, section: item.section)
                case let .media(media):
                    MediaCell(media: media, section: item.section)
                case .showPlaceholder:
                    ShowCell(show: nil, section: item.section)
                case let .show(show):
                    ShowCell(show: show, section: item.section)
                case .topicPlaceholder:
                    TopicCell(topic: nil)
                case let .topic(topic):
                    TopicCell(topic: topic)
                #if os(iOS)
                case .showAccess:
                    ShowAccessCell()
                #endif
                }
            case .more:
                MoreCell(section: item.section.wrappedValue, filter: id)
            }
        }
    }
}

// MARK: Headers

@objc private protocol SectionHeaderViewAction {
    func openSection(sender: Any?, event: OpenSectionEvent?)
}

private class OpenSectionEvent: UIEvent {
    let section: PageViewModel.Section
    
    init(section: PageViewModel.Section) {
        self.section = section
        super.init()
    }
    
    override init() {
        fatalError("init() is not available")
    }
}

private extension PageViewController {
    private struct SectionHeaderView: View {
        let section: PageViewModel.Section
        let pageId: PageViewModel.Id
        
        @AppStorage(PlaySRGSettingSectionWideSupportEnabled) var isSectionWideSupportEnabled = false
        
        private static func title(for section: PageViewModel.Section) -> String? {
            return section.properties.title
        }
        
        private static func subtitle(for section: PageViewModel.Section) -> String? {
            return section.properties.summary
        }
        
        private var hasDetailDisclosure: Bool {
            return section.viewModelProperties.canOpenDetailPage || isSectionWideSupportEnabled
        }
        
        var accessibilityLabel: String? {
            return Self.title(for: section)
        }
        
        var accessibilityHint: String? {
            return hasDetailDisclosure ? PlaySRGAccessibilityLocalizedString("Shows all contents.", comment: "Homepage header action hint") : nil
        }
        
        var body: some View {
            if let title = Self.title(for: section) {
                #if os(tvOS)
                HeaderView(title: title, subtitle: Self.subtitle(for: section), hasDetailDisclosure: false)
                    .accessibilityElement(label: accessibilityLabel, traits: .isHeader)
                #else
                ResponderChain { firstResponder in
                    Button {
                        firstResponder.sendAction(#selector(SectionHeaderViewAction.openSection(sender:event:)), for: OpenSectionEvent(section: section))
                    } label: {
                        HeaderView(title: title, subtitle: Self.subtitle(for: section), hasDetailDisclosure: hasDetailDisclosure)
                    }
                    .disabled(!hasDetailDisclosure)
                    .accessibilityElement(label: accessibilityLabel, hint: accessibilityHint, traits: .isHeader)
                }
                #endif
            }
        }
        
        static func size(section: PageViewModel.Section, layoutWidth: CGFloat) -> NSCollectionLayoutSize {
            return HeaderViewSize.recommended(title: title(for: section), subtitle: subtitle(for: section), layoutWidth: layoutWidth)
        }
    }
}
