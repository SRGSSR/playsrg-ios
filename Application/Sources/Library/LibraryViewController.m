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
#import "UIScrollView+PlaySRG.h"
#import "UIViewController+PlaySRG.h"
#import "WatchLaterViewController.h"
#import "WebViewController.h"

#import <SRGAppearance/SRGAppearance.h>
#import <SRGIdentity/SRGIdentity.h>

@interface LibraryViewController ()

@property (nonatomic) NSArray<Notification *> *unreadNotifications;
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

#pragma mark Getters and setters

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
    
    // Ensure correct notification badge on notification cell
    [self reloadData];
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

#pragma mark UI

- (void)scrollToTopAnimated:(BOOL)animated
{
    [self.tableView play_scrollToTopAnimated:animated];
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
    if (self.unreadNotifications && section == 0) {
        return self.unreadNotifications.count;
    }
    else {
        return self.sectionInfos[section].menuItemInfos.count;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.unreadNotifications && indexPath.section == 0) {
        return [tableView dequeueReusableCellWithIdentifier:NSStringFromClass(NotificationTableViewCell.class) forIndexPath:indexPath];
    }
    else {
        return [tableView dequeueReusableCellWithIdentifier:NSStringFromClass(LibraryTableViewCell.class) forIndexPath:indexPath];
    }
}

#pragma mark UITableViewDelegate protocol

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.unreadNotifications && indexPath.section == 0) {
        NSString *contentSizeCategory = UIApplication.sharedApplication.preferredContentSizeCategory;
        return (SRGAppearanceCompareContentSizeCategories(contentSizeCategory, UIContentSizeCategoryExtraLarge) == NSOrderedAscending) ? 94.f : 110.f;
    }
    else {
        return 50.f;
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.unreadNotifications && indexPath.section == 0) {
        NotificationTableViewCell *notificationTableViewCell = (NotificationTableViewCell *)cell;
        notificationTableViewCell.notification = self.unreadNotifications[indexPath.row];
    }
    else {
        LibraryTableViewCell *libraryTableViewCell = (LibraryTableViewCell *)cell;
        MenuItemInfo *menuItemInfo = self.sectionInfos[indexPath.section].menuItemInfos[indexPath.row];
        libraryTableViewCell.menuItemInfo = menuItemInfo;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.unreadNotifications && indexPath.section == 0) {
        Notification *notification = self.unreadNotifications[indexPath.row];
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

#pragma mark Actions

- (void)reloadData
{
    NSArray<Notification *> *unreadNotifications = Notification.unreadNotifications;
    self.unreadNotifications = unreadNotifications.count > 3 ? @[ unreadNotifications[0], unreadNotifications[1], unreadNotifications[2] ] : unreadNotifications.count > 0 ? unreadNotifications : nil;
    
    self.sectionInfos = MenuSectionInfo.libraryMenuSectionInfos;
    
    if (self.unreadNotifications) {
        MenuSectionInfo *unreadNotificationsSectionInfo = [[MenuSectionInfo alloc] initWithTitle:NSLocalizedString(@"Latest notifications", @"Miscellaneous menu section header label")
                                                                                   menuItemInfos:@[]
                                                                                      headerless:YES];
        self.sectionInfos = [@[ unreadNotificationsSectionInfo ] arrayByAddingObjectsFromArray:self.sectionInfos];
    }
    
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
    // Ensure correct notification badge on notification cell availability after:
    //   - Dismissal of the initial system alert (displayed once at most), asking the user to enable push notifications.
    //   - Returning from system settings, where the user might have updated push notification authorizations.
    [self reloadData];
}

- (void)didReceiveNotification:(NSNotification *)notification
{
    // Ensure correct notification badge on notification cell
    [self reloadData];
}

- (void)badgeDidChange:(NSNotification *)notification
{
    // Ensure correct notification badge on notification cell
    [self reloadData];
}

@end
