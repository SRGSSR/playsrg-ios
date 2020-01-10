//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "LibraryViewController.h"

#import "ApplicationConfiguration.h"
#import "ContentInsets.h"
#import "DownloadsViewController.h"
#import "FavoritesViewController.h"
#import "HistoryViewController.h"
#import "LibraryAccountHeaderView.h"
#import "LibraryHeaderSectionView.h"
#import "LibraryTableViewCell.h"
#import "MenuSectionInfo.h"
#import "NotificationsViewController.h"
#import "NSBundle+PlaySRG.h"
#import "PushService.h"
#import "SettingsViewController.h"
#import "UIColor+PlaySRG.h"
#import "UIDevice+PlaySRG.h"
#import "UIViewController+PlaySRG.h"
#import "WatchLaterViewController.h"
#import "WebViewController.h"

#import <SRGAppearance/SRGAppearance.h>
#import <SRGIdentity/SRGIdentity.h>

@interface LibraryViewController ()

@property (nonatomic) NSArray<MenuSectionInfo *> *sectionInfos;

@property (nonatomic, weak) IBOutlet UITableView *tableView;

@end

@implementation LibraryViewController

#pragma mark Object lifecycle

- (instancetype)init
{
    if (self = [super init]) {
        self.title = NSLocalizedString(@"Library", @"Title displayed at the top of the library view");
    }
    return self;
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = UIColor.play_blackColor;
    
    self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    
    if (SRGIdentityService.currentIdentityService) {
        self.tableView.tableHeaderView = [LibraryAccountHeaderView view];
    }
    
    Class headerClass = LibraryHeaderSectionView.class;
    [self.tableView registerClass:LibraryHeaderSectionView.class forHeaderFooterViewReuseIdentifier:NSStringFromClass(headerClass)];
    
    NSString *cellIdentifier = NSStringFromClass(NotificationTableViewCell.class);
    UINib *cellNib = [UINib nibWithNibName:cellIdentifier bundle:nil];
    [self.tableView registerNib:cellNib forCellReuseIdentifier:cellIdentifier];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(accessibilityVoiceOverStatusChanged:)
                                               name:UIAccessibilityVoiceOverStatusChanged
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(applicationConfigurationDidChange:)
                                               name:ApplicationConfigurationDidChangeNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didReceiveNotification:)
                                               name:PushServiceDidReceiveNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(applicationDidBecomeActive:)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(applicationWillResignActive:)
                                               name:UIApplicationWillResignActiveNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(badgeDidChange:)
                                               name:PushServiceBadgeDidChangeNotification
                                             object:nil];
    
    UIBarButtonItem *settingsBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"settings-22"]
                                                                              style:UIBarButtonItemStyleDone
                                                                             target:self
                                                                             action:@selector(settings:)];
       settingsBarButtonItem.accessibilityLabel = PlaySRGAccessibilityLocalizedString(@"Settings", @"Settings button label on home view");
       self.navigationItem.rightBarButtonItem = settingsBarButtonItem;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [PushService.sharedService resetApplicationBadge];
    
    // Ensure correct latest notifications displayed
    [self reloadData];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if ([self play_isMovingFromParentViewController]) {
        [PushService.sharedService resetApplicationBadge];
    }
}

#pragma mark Rotation

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return [super supportedInterfaceOrientations] & UIViewController.play_supportedInterfaceOrientations;
}

#pragma mark Status bar

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

#pragma mark Accessibility

- (void)updateForContentSizeCategory
{
    [super updateForContentSizeCategory];
    
    [self.tableView reloadData];
}

#pragma mark ContentInsets protocol

- (NSArray<UIScrollView *> *)play_contentScrollViews
{
    return self.tableView ? @[self.tableView] : nil;
}

- (UIEdgeInsets)play_paddingContentInsets
{
    return UIEdgeInsetsZero;
}

#pragma mark SRGAnalyticsViewTracking protocol

- (NSString *)srg_pageViewTitle
{
    return NSLocalizedString(@"Library", @"[Technical] Title for library analytics measurements");
}

- (NSArray<NSString *> *)srg_pageViewLevels
{
    return @[ AnalyticsNameForPageType(AnalyticsPageTypeUser) ];
}

#pragma mark UITableViewDataSource protocol

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.sectionInfos.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.sectionInfos[section].menuItemInfos.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self isNotificationForIndex:indexPath]) {
        return [tableView dequeueReusableCellWithIdentifier:NSStringFromClass(NotificationTableViewCell.class) forIndexPath:indexPath];
    }
    else {
        return [tableView dequeueReusableCellWithIdentifier:NSStringFromClass(LibraryTableViewCell.class) forIndexPath:indexPath];
    }
}

#pragma mark UITableViewDelegate protocol

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self isNotificationForIndex:indexPath]) {
        NSString *contentSizeCategory = UIApplication.sharedApplication.preferredContentSizeCategory;
        return (SRGAppearanceCompareContentSizeCategories(contentSizeCategory, UIContentSizeCategoryExtraLarge) == NSOrderedAscending) ? 94.f : 110.f;
    }
    else {
        return 50.f;
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    Notification *notification = [self notificationForIndex:indexPath];
    if (notification) {
        NotificationTableViewCell *notificationTableViewCell = (NotificationTableViewCell *)cell;
        notificationTableViewCell.notification = notification;
    }
    else {
        LibraryTableViewCell *libraryTableViewCell = (LibraryTableViewCell *)cell;
        MenuItemInfo *menuItemInfo = self.sectionInfos[indexPath.section].menuItemInfos[indexPath.row];
        libraryTableViewCell.menuItemInfo = menuItemInfo;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    Notification *notification = [self notificationForIndex:indexPath];
    if (notification) {
        [NotificationsViewController openNotification:notification fromViewController:self];
        [tableView reloadData];
    }
    else {
        MenuItemInfo *menuItemInfo = self.sectionInfos[indexPath.section].menuItemInfos[indexPath.row];
        [self openMenuItemInfo:menuItemInfo animated:YES];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    MenuSectionInfo *sectionInfo = self.sectionInfos[section];
    return [LibraryHeaderSectionView heightForMenuSectionInfo:sectionInfo];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    LibraryHeaderSectionView *headerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:NSStringFromClass(LibraryHeaderSectionView.class)];
    headerView.menuSectionInfo = self.sectionInfos[section];
    return headerView;
}
#pragma mark Helpers

- (BOOL)isNotificationForIndex:(NSIndexPath *)indexPath
{
    return self.sectionInfos[indexPath.section].menuItemInfos[indexPath.row].menuItem == MenuItemNotification;
}

- (Notification *)notificationForIndex:(NSIndexPath *)indexPath
{
    if ([self isNotificationForIndex:indexPath]) {
        MenuItemInfo *menuItemInfo = self.sectionInfos[indexPath.section].menuItemInfos[indexPath.row];
        return menuItemInfo.options[MenuItemOptionNotificationKey];
    }
    else {
        return nil;
    }
}

#pragma mark Actions

- (void)reloadData
{
    self.sectionInfos = MenuSectionInfo.libraryMenuSectionInfos;
    [self.tableView reloadData];
}

- (void)settings:(id)sender
{
    SettingsViewController *settingsViewController = [[SettingsViewController alloc] init];
    [self.navigationController pushViewController:settingsViewController animated:YES];
}

- (void)openMenuItemInfo:(MenuItemInfo *)menuItemInfo animated:(BOOL)animated
{
    ApplicationConfiguration *applicationConfiguration = ApplicationConfiguration.sharedApplicationConfiguration;
    
    UIViewController *viewController = nil;
    switch (menuItemInfo.menuItem) {
        case MenuItemNotifications: {
            viewController = [[NotificationsViewController alloc] init];
            break;
        }
            
        case MenuItemHistory: {
            viewController = [[HistoryViewController alloc] init];
            break;
        }
            
        case MenuItemFavorites: {
            viewController = [[FavoritesViewController alloc] init];
            break;
        }
            
        case MenuItemWatchLater: {
            viewController = [[WatchLaterViewController alloc] init];
            break;
        }
            
        case MenuItemDownloads: {
            viewController = [[DownloadsViewController alloc] init];
            break;
        }
            
        case MenuItemFeedback: {
            NSAssert(applicationConfiguration.feedbackURL, @"Feedback URL expected");
            
            NSMutableArray *queryItems = [NSMutableArray array];
            [queryItems addObject:[NSURLQueryItem queryItemWithName:@"platform" value:@"iOS"]];
            
            NSString *appVersion = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
            [queryItems addObject:[NSURLQueryItem queryItemWithName:@"version" value:appVersion]];
            
            BOOL isPad = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
            [queryItems addObject:[NSURLQueryItem queryItemWithName:@"type" value:isPad ? @"tablet" : @"phone"]];
            [queryItems addObject:[NSURLQueryItem queryItemWithName:@"model" value:UIDevice.currentDevice.model]];
            
            NSString *tagCommanderUid = [NSUserDefaults.standardUserDefaults stringForKey:@"tc_unique_id"];
            if (tagCommanderUid) {
                [queryItems addObject:[NSURLQueryItem queryItemWithName:@"cid" value:tagCommanderUid]];
            }
            
            NSURL *feedbackURL = applicationConfiguration.feedbackURL;
            NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:feedbackURL resolvingAgainstBaseURL:NO];
            URLComponents.queryItems = queryItems.copy;
            
            NSURLRequest *request = [NSURLRequest requestWithURL:URLComponents.URL];
            viewController = [[WebViewController alloc] initWithRequest:request customizationBlock:^(WKWebView *webView) {
                webView.scrollView.scrollEnabled = NO;
            } decisionHandler:nil analyticsPageType:AnalyticsPageTypeSystem];
            viewController.title = NSLocalizedString(@"Your feedback", @"Title displayed at the top of the feedback view");
            break;
        }
            
        case MenuItemHelp: {
            NSAssert(applicationConfiguration.impressumURL, @"Impressum URL expected");
            NSURLRequest *request = [NSURLRequest requestWithURL:applicationConfiguration.impressumURL];
            WebViewController *impressumWebViewController = [[WebViewController alloc] initWithRequest:request customizationBlock:^(WKWebView * _Nonnull webView) {
                webView.scrollView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
            } decisionHandler:nil analyticsPageType:AnalyticsPageTypeSystem];
            impressumWebViewController.title = NSLocalizedString(@"Help and copyright", @"Title displayed at the top of the help and copyright view");
            impressumWebViewController.tracked = NO;            // The website we display is already tracked.
            viewController = impressumWebViewController;
            break;
        }
            
        default: {
            return;
            break;
        }
    }
    
    if (viewController) {
        [self.navigationController pushViewController:viewController animated:YES];
    }
}

#pragma mark Notifications

- (void)accessibilityVoiceOverStatusChanged:(NSNotification *)notification
{
    [self reloadData];
}

- (void)applicationConfigurationDidChange:(NSNotification *)notification
{
    // Update sections.
    [self reloadData];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    if (self.viewVisible) {
        [PushService.sharedService resetApplicationBadge];
        
        // Ensure correct notification badge on notification cell availability after:
        //   - Dismissal of the initial system alert (displayed once at most), asking the user to enable push notifications.
        //   - Returning from system settings, where the user might have updated push notification authorizations.
        [self reloadData];
    }
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    if (self.viewVisible) {
        [PushService.sharedService resetApplicationBadge];
    }
}

- (void)didReceiveNotification:(NSNotification *)notification
{
    // Ensure correct latest notifications displayed
    [self reloadData];
}

- (void)badgeDidChange:(NSNotification *)notification
{
    // Ensure correct latest notifications displayed
    [self reloadData];
}

@end