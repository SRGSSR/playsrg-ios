//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import Masonry
import paper_onboarding
import SRGAppearance

@objc(OnboardingViewController) public class OnboardingViewController : BaseViewController, PaperOnboardingDataSource, PaperOnboardingDelegate {
    
    final var onboarding: Onboarding!
    
    weak var paperOnboarding: PaperOnboarding!
    
    @IBOutlet weak var previousButton: UIButton!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    
    @IBOutlet weak var buttonBottomConstraint: NSLayoutConstraint!
    
    var isTall: Bool {
        get {
            return self.view.frame.height >= 600.0
        }
    }
    
    // MARK: Object lifecycle
    
    @objc init(onboarding: Onboarding!) {
        super.init(storyboardName: nil, bundle: nil)
        
        self.onboarding = onboarding
        self.title = onboarding.title
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    // MARK: View lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.previousButton.setTitleColor(.white, for: .normal)
        self.previousButton.setTitle(NSLocalizedString("Previous", comment: "Title of the button to proceed to the previous onboarding page"), for: .normal)
        
        self.closeButton.setTitleColor(.white, for: .normal)
        self.closeButton.setTitle(NSLocalizedString("OK", comment: "Title of the button displayed at the end of an onboarding"), for: .normal)
        
        self.nextButton.setTitleColor(.white, for: .normal)
        self.nextButton.setTitle(NSLocalizedString("Next", comment: "Title of the button to proceed to the next onboarding page"), for: .normal)
        
        // Set tint color to white. Cannot easily customize colors on a page basis (page control current item color
        // cannot be customized). Force the text to be white.
        let paperOnboarding = PaperOnboarding()
        paperOnboarding.tintColor = .white
        
        // Set the delegate before the data source so that all delegate methods are correctly called when loading the
        // first page (sigh).
        paperOnboarding.delegate = self
        paperOnboarding.dataSource = self
        self.view.insertSubview(paperOnboarding, at: 0)
        self.paperOnboarding = paperOnboarding
        
        paperOnboarding.mas_makeConstraints { make in
            make?.edges.equalTo()(self.view)
        }
        
        self.updateUserInterface(index: 0, animated: false)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(accessibilityVoiceOverStatusChanged(notification:)),
                                               name: NSNotification.Name(rawValue: UIAccessibilityVoiceOverStatusChanged),
                                               object: nil)
    }
    
    // MARK: Rotation
    
    public override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        if (UIDevice.current.userInterfaceIdiom == .pad) {
            return .all
        }
        else {
            return .portrait
        }
    }
    
    // MARK: Status bar
    
    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    // MARK: Overrides
    
    public override var pageType: AnalyticsPageType {
        get {
            return .onboarding
        }
    }
    
    public override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        let isTall = self.isTall
        let smallFontSize = CGFloat(isTall ? 20.0 : 14.0)
        let largeFontSize = CGFloat(isTall ? 24.0 : 16.0)
        
        self.previousButton.titleLabel?.font = UIFont.srg_mediumFont(withSize: smallFontSize)
        self.closeButton.titleLabel?.font = UIFont.srg_mediumFont(withSize: largeFontSize)
        self.nextButton.titleLabel?.font = UIFont.srg_mediumFont(withSize: smallFontSize)
        
        self.buttonBottomConstraint.constant = 0.19 * self.view.frame.height;
    }
    
    // MARK: User interface
    
    private func updateUserInterface(index: Int, animated: Bool) {
        let isFirstPage = (index == 0)
        let isLastPage = (index == self.onboarding.pages.count - 1)
        
        let animations: () -> (Void) = {
            self.closeButton.alpha = isLastPage ? 1.0 : 0.0
            
            let voiceOverEnabled = UIAccessibility.isVoiceOverRunning
            self.previousButton.alpha = (voiceOverEnabled && !isFirstPage) ? 1.0 : 0.0
            self.nextButton.alpha = (voiceOverEnabled && !isLastPage) ? 1.0 : 0.0
        }
        
        if animated {
            UIView.animate(withDuration: 0.2, animations: animations)
        }
        else {
            animations()
        }
    }
    
    // MARK: PaperOnboardingDataSource protocol
    
    public func onboardingItemsCount() -> Int {
        return self.onboarding.pages.count
    }
    
    public func onboardingItem(at index: Int) -> OnboardingItemInfo {
        let page = self.onboarding.pages[index]
        
        let informationImage = UIImage(named: "\(onboarding.uid)_\(page.uid)-200") ?? UIImage.init()
        let pageIcon = UIImage(named: "\(onboarding.uid)_\(page.uid)-45") ?? UIImage.init()
        
        let isTall = self.isTall
        let titleFontSize = CGFloat(isTall ? 24.0 : 20.0)
        let subtitleFontSize = CGFloat(isTall ? 15.0 : 14.0)
        
        return OnboardingItemInfo(informationImage: informationImage,
                                  title: PlaySRGOnboardingLocalizedString(page.title, nil),
                                  description: PlaySRGOnboardingLocalizedString(page.text, nil),
                                  pageIcon: pageIcon,
                                  color: page.color,
                                  titleColor: .white,
                                  descriptionColor: .white,
                                  titleFont: UIFont.srg_mediumFont(withSize: titleFontSize),
                                  descriptionFont: UIFont.srg_mediumFont(withSize: subtitleFontSize),
                                  descriptionLabelPadding: 30.0,
                                  titleLabelPadding: 15.0)
    }
    
    // MARK: PaperOnboardingDelegate protocol
    
    public func onboardingWillTransitonToIndex(_ index: Int) {
        self.updateUserInterface(index: index, animated: true)
    }
    
    public func onboardingDidTransitonToIndex(_: Int) {
        UIAccessibility.post(notification: UIAccessibility.Notification.screenChanged, argument: self.paperOnboarding);
    }
    
    public func onboardingConfigurationItem(_ item: OnboardingContentViewItem, index _: Int) {
        item.titleLabel?.numberOfLines = 2;
        item.descriptionLabel?.numberOfLines = 0;
        
        let constant = CGFloat(self.isTall ? 200.0 : 120.0)
        item.informationImageWidthConstraint?.constant = constant
        item.informationImageHeightConstraint?.constant = constant
        
        item.titleCenterConstraint?.constant = isTall ? 50.0 : 20.0
    }
    
    // MARK: Actions
    
    @IBAction private func previousPage(_ sender: UIButton) {
        self.paperOnboarding.currentIndex(self.paperOnboarding.currentIndex - 1, animated: true)
    }
    
    @IBAction private func close(_ sender: UIButton) {
        if (self.onboarding.uid == "favorites" || self.onboarding.uid == "favorites_account") {
            PushService.shared?.presentSystemAlertForPushNotifications()
        }
        self.dismiss(animated: true, completion: {
            if (self.onboarding.uid == "account") {
                let playAppDelegate = UIApplication.shared.delegate as! PlayAppDelegate
                playAppDelegate.playTabBarController.displayAccountHeader(animated: true)
            }
        });
    }
    
    @IBAction private func nextPage(_ sender: UIButton) {
        self.paperOnboarding.currentIndex(self.paperOnboarding.currentIndex + 1, animated: true)
    }
    
    // MARK: Notifications
    
    @objc private func accessibilityVoiceOverStatusChanged(notification: NSNotification) {
        self.updateUserInterface(index: self.paperOnboarding.currentIndex, animated: true)
    }
}
