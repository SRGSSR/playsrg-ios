//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import Combine
import UIKit

// MARK: View controller

final class ProgramGuideViewController: UIViewController {
    private let model = ProgramGuideViewModel()
    private let pageViewController: UIPageViewController
    
    private var selectedChannel: SRGChannel?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: [
            UIPageViewController.OptionsKey.interPageSpacing: 100
        ])
        super.init(nibName: nil, bundle: nil)
        title = NSLocalizedString("Program guide", comment: "Program guide title")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .srgGray16
        self.view = view
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        pageViewController.dataSource = self
        pageViewController.delegate = self
        
        addChild(pageViewController)
        if let pageView = pageViewController.view {
            pageView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(pageView)
            
            NSLayoutConstraint.activate([
                pageView.topAnchor.constraint(equalTo: view.topAnchor),
                pageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                pageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                pageView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
        }
        pageViewController.didMove(toParent: self)
        
        model.$states
            .sink { [weak self] states in
                self?.reloadData(for: states)
            }
            .store(in: &cancellables)
        
        let todayViewController = ProgramGuideDailyViewController(day: .today, parentModel: model)
        pageViewController.setViewControllers([todayViewController], direction: .forward, animated: false, completion: nil)
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return Self.play_supportedInterfaceOrientations
    }
    
    private func reloadData(for states: [SRGDay: ProgramGuideViewModel.State]) {
        let channels = ProgramGuideViewModel.State.channels(from: Array(states.values))
        if channels.count != 0 {
            if selectedChannel == nil {
                selectedChannel = channels.first
            }
            if let title = selectedChannel?.title {
                navigationItem.rightBarButtonItem = UIBarButtonItem(title: title, style: .plain, target: self, action: #selector(changeChannel))
            }
            else {
                navigationItem.rightBarButtonItem = nil
            }
        }
        else {
            selectedChannel = nil
            navigationItem.rightBarButtonItem = nil
        }
    }
    
    // TODO: Remove right bar button item related code
    @objc private func changeChannel(_ sender: UIBarButtonItem) {
        let channels = ProgramGuideViewModel.State.channels(from: Array(model.states.values))
        guard let selectedChannel = selectedChannel,
              let index = channels.firstIndex(of: selectedChannel),
              let currentViewController = pageViewController.viewControllers?.first as? ProgramGuideDailyViewController else {
            return
        }
        
        let nextIndex = (index + 1) % channels.count
        self.selectedChannel = channels[nextIndex]
        currentViewController.channel = self.selectedChannel
        
        reloadData(for: model.states)
    }
}

extension ProgramGuideViewController: UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let currentViewController = viewController as? ProgramGuideDailyViewController else { return nil }
        let previousDay = SRGDay(byAddingDays: -1, months: 0, years: 0, to: currentViewController.day)
        
        let viewController = ProgramGuideDailyViewController(day: previousDay, parentModel: model)
        viewController.channel = selectedChannel
        return viewController
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let currentViewController = viewController as? ProgramGuideDailyViewController else { return nil }
        let nextDay = SRGDay(byAddingDays: 1, months: 0, years: 0, to: currentViewController.day)
        
        let viewController = ProgramGuideDailyViewController(day: nextDay, parentModel: model)
        viewController.channel = selectedChannel
        return viewController
    }
}

extension ProgramGuideViewController: UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        // TODO: Update header
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        // TODO: Update header
    }
}
