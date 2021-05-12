//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import Combine
import SRGAppearanceSwift
import SRGDataProviderModel
import UIKit

class PageViewController: DataViewController {
    enum Header: String {
        case global
    }
    
    private let model: PageModel
    private var refreshCancellables = Set<AnyCancellable>()

    private var dataSource: UICollectionViewDiffableDataSource<PageModel.Section, PageModel.Item>!
    
    private weak var collectionView: UICollectionView!
    private weak var emptyView: HostView<EmptyView>!
    
    #if os(iOS)
    private weak var refreshControl: UIRefreshControl!
    #endif
    
    private var refreshTriggered = false
    
    #if os(iOS)
    private typealias CollectionView = DampedCollectionView
    #else
    private typealias CollectionView = UICollectionView
    #endif
    
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
    
    private static func snapshot(from state: PageModel.State) -> NSDiffableDataSourceSnapshot<PageModel.Section, PageModel.Item> {
        var snapshot = NSDiffableDataSourceSnapshot<PageModel.Section, PageModel.Item>()
        if case let .loaded(rows: rows) = state {
            for row in rows {
                snapshot.appendSections([row.section])
                snapshot.appendItems(row.items, toSection: row.section)
            }
        }
        return snapshot
    }
    
    init(id: PageModel.Id) {
        self.model = PageModel(id: id)
        super.init(nibName: nil, bundle: nil)
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
        view.backgroundColor = .play_black
        
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
        
        let cellRegistration = UICollectionView.CellRegistration<HostCollectionViewCell<PageCell>, PageModel.Item> { cell, _, item in
            cell.content = PageCell(item: item)
        }
        
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }
        
        let globalHeaderViewRegistration = UICollectionView.SupplementaryRegistration<HostSupplementaryView<TitleView>>(elementKind: Header.global.rawValue) { [weak self] view, _, section in
            guard let self = self else { return }
            view.content = TitleView(text: self.model.title)
        }
        
        let sectionHeaderViewRegistration = UICollectionView.SupplementaryRegistration<HostSupplementaryView<PageSectionHeaderView>>(elementKind: UICollectionView.elementKindSectionHeader) { [weak self] view, _, indexPath in
            guard let self = self else { return }
            let snapshot = self.dataSource.snapshot()
            let section = snapshot.sectionIdentifiers[indexPath.section]
            view.content = PageSectionHeaderView(section: section)
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
                self?.reloadData(with: state)
            }
            .store(in: &refreshCancellables)
    }
    
    #if os(iOS)
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return Self.play_supportedInterfaceOrientations
    }
    #endif
    
    override func refresh() {
        model.refresh()
    }
    
    func reloadData(with state: PageModel.State) {
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

/// Layout setup
extension PageViewController {
    private static let sectionSpacing: CGFloat = constant(iOS: 35, tvOS: 70)
    private static let itemSpacing: CGFloat = constant(iOS: 8, tvOS: 40)
    private static let sectionTop: CGFloat = constant(iOS: 3, tvOS: 15)
    private static let layoutVerticalMargin: CGFloat = constant(iOS: 8, tvOS: 0)
    
    private func layoutConfiguration() -> UICollectionViewCompositionalLayoutConfiguration {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.interSectionSpacing = Self.sectionSpacing
        
        let headerSize = TitleViewSize.recommended(text: model.title)
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: Header.global.rawValue, alignment: .top)
        configuration.boundarySupplementaryItems = [header]
        
        return configuration
    }
    
    private func layout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout(sectionProvider: { [weak self] sectionIndex, layoutEnvironment in
            func sectionSupplementaryItems(for section: PageModel.Section, index: Int) -> [NSCollectionLayoutBoundarySupplementaryItem] {
                let headerSize = PageSectionHeaderView.size(section: section, horizontalSizeClass: layoutEnvironment.traitCollection.horizontalSizeClass)
                let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .topLeading)
                return [header]
            }
            
            func layoutSection(for section: PageModel.Section, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
                let layoutWidth = layoutEnvironment.container.effectiveContentSize.width
                let horizontalSizeClass = layoutEnvironment.traitCollection.horizontalSizeClass
                
                switch section.properties.layout {
                case .hero:
                    let layoutSection = NSCollectionLayoutSection.horizontal(layoutWidth: layoutWidth, spacing: Self.itemSpacing, top: Self.sectionTop) { (layoutWidth, _) in
                        return FeaturedContentCellSize.hero(layoutWidth: layoutWidth, horizontalSizeClass: horizontalSizeClass)
                    }
                    layoutSection.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary
                    return layoutSection
                case .highlight:
                    return NSCollectionLayoutSection.horizontal(layoutWidth: layoutWidth, spacing: Self.itemSpacing, top: Self.sectionTop) { (layoutWidth, _) in
                        return FeaturedContentCellSize.highlight(layoutWidth: layoutWidth, horizontalSizeClass: horizontalSizeClass)
                    }
                case .mediaSwimlane:
                    let layoutSection = NSCollectionLayoutSection.horizontal(layoutWidth: layoutWidth, spacing: Self.itemSpacing, top: Self.sectionTop) { _ in
                        return MediaCellSize.swimlane()
                    }
                    layoutSection.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary
                    return layoutSection
                case .liveMediaSwimlane:
                    let layoutSection = NSCollectionLayoutSection.horizontal(layoutWidth: layoutWidth, spacing: Self.itemSpacing, top: Self.sectionTop) { _ in
                        return LiveMediaCellSize.swimlane()
                    }
                    layoutSection.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary
                    return layoutSection
                case .showSwimlane:
                    let layoutSection = NSCollectionLayoutSection.horizontal(layoutWidth: layoutWidth, spacing: Self.itemSpacing, top: Self.sectionTop) { _ in
                        return ShowCellSize.swimlane()
                    }
                    layoutSection.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary
                    return layoutSection
                case .topicSelector:
                    let layoutSection = NSCollectionLayoutSection.horizontal(layoutWidth: layoutWidth, spacing: Self.itemSpacing, top: Self.sectionTop) { _ in
                        return TopicCellSize.swimlane()
                    }
                    layoutSection.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary
                    return layoutSection
                case .mediaGrid:
                    if horizontalSizeClass == .compact {
                        return NSCollectionLayoutSection.horizontal(layoutWidth: layoutWidth, spacing: Self.itemSpacing, top: Self.sectionTop) { _ in
                            return MediaCellSize.fullWidth()
                        }
                    }
                    else {
                        return NSCollectionLayoutSection.grid(layoutWidth: layoutWidth, spacing: Self.itemSpacing, top: Self.sectionTop) { (layoutWidth, spacing) in
                            return MediaCellSize.grid(layoutWidth: layoutWidth, spacing: Self.itemSpacing, minimumNumberOfColumns: 1)
                        }
                    }
                case .liveMediaGrid:
                    return NSCollectionLayoutSection.grid(layoutWidth: layoutWidth, spacing: Self.itemSpacing, top: Self.sectionTop) { (layoutWidth, spacing) in
                        return LiveMediaCellSize.grid(layoutWidth: layoutWidth, spacing: Self.itemSpacing, minimumNumberOfColumns: 2)
                    }
                case .showGrid:
                    return NSCollectionLayoutSection.grid(layoutWidth: layoutWidth, spacing: Self.itemSpacing, top: Self.sectionTop) { (layoutWidth, spacing) in
                        return ShowCellSize.grid(layoutWidth: layoutWidth, spacing: Self.itemSpacing, minimumNumberOfColumns: 2)
                    }
                #if os(iOS)
                case .showAccess:
                    return NSCollectionLayoutSection.horizontal(layoutWidth: layoutWidth, spacing: Self.itemSpacing, top: Self.sectionTop) { (layoutWidth, _) in
                        return ShowAccessCellSize.fullWidth(layoutWidth: layoutWidth)
                    }
                #endif
                }
            }
            
            guard let self = self else { return nil }
            
            let snapshot = self.dataSource.snapshot()
            let section = snapshot.sectionIdentifiers[sectionIndex]
            
            let layoutSection = layoutSection(for: section, layoutEnvironment: layoutEnvironment)
            layoutSection.boundarySupplementaryItems = sectionSupplementaryItems(for: section, index: sectionIndex)
            return layoutSection
        }, configuration: layoutConfiguration())
    }
}

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
        
        switch item {
        case let .media(media, section: _):
            play_presentMediaPlayer(with: media, position: nil, airPlaySuggestions: true, fromPushNotification: false, animated: true, completion: nil)
        case let .show(show, section: _):
            if let navigationController = navigationController {
                let showViewController = ShowViewController(show: show, fromPushNotification: false)
                navigationController.pushViewController(showViewController, animated: true)
            }
        case let .topic(topic, section: _):
            if let navigationController = navigationController {
                let pageViewController = PageViewController(id: .topic(topic: topic))
                // TODO: Should the title be managed based on the PageViewController id? Depending on the answer,
                //       check -[PlayAppDelegate openTopicURN:]
                pageViewController.title = topic.title
                navigationController.pushViewController(pageViewController, animated: true)
            }
        default:
            ()
        }
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
            refresh()
            refreshTriggered = false
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
            let calendarViewController = CalendarViewController(radioChannel: radioChannel, date: nil)
            navigationController.pushViewController(calendarViewController, animated: true)
        }
    }
}

extension PageViewController: SectionHeaderViewAction {
    func openSection(sender: Any?, event: UIEvent?) {
        guard let event = event as? OpenSectionEvent else { return }

        if let navigationController = navigationController {
            let sectionViewController = PageViewController.init(id: .section(section: event.section))
            sectionViewController.title = event.section.properties.title
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

// TODO: Remaining protocols to implement, as was the case for HomeViewController

#if false

extension PageViewController: PlayApplicationNavigation {
    
}

extension PageViewController: SRGAnalyticsViewTracking {
    
}

#endif
