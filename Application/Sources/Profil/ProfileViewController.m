//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "ProfileViewController.h"

#import "ApplicationConfiguration.h"
#import "ContentInsets.h"
#import "DownloadsViewController.h"
#import "FavoritesViewController.h"
#import "HistoryViewController.h"
#import "MenuSectionInfo.h"
#import "NSBundle+PlaySRG.h"
#import "ProfileAccountHeaderView.h"
#import "ProfileHeaderSectionView.h"
#import "ProfileTableViewCell.h"
#import "SettingsViewController.h"
#import "UIDevice+PlaySRG.h"
#import "UIScrollView+PlaySRG.h"
#import "UIViewController+PlaySRG.h"
#import "WatchLaterViewController.h"
#import "WebViewController.h"

#import <SRGIdentity/SRGIdentity.h>

@interface ProfileViewController ()

@property (nonatomic) NSArray<MenuSectionInfo *> *sectionInfos;

@property (nonatomic, weak) IBOutlet UITableView *tableView;

@end

@implementation ProfileViewController

#pragma mark Object lifecycle

- (instancetype)init
{
    if (self = [super init]) {
        self.title = NSLocalizedString(@"Profile", @"Title displayed at the top of the profile view");
        self.sectionInfos = MenuSectionInfo.profileMenuSectionInfos;
    }
    return self;
}

#pragma mark Getters and setters

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    
    if (SRGIdentityService.currentIdentityService) {
        self.tableView.tableHeaderView = [ProfileAccountHeaderView view];
    }
    
    Class headerClass = ProfileHeaderSectionView.class;
    [self.tableView registerClass:ProfileHeaderSectionView.class forHeaderFooterViewReuseIdentifier:NSStringFromClass(headerClass)];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(accessibilityVoiceOverStatusChanged:)
                                               name:UIAccessibilityVoiceOverStatusChanged
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(applicationConfigurationDidChange:)
                                               name:ApplicationConfigurationDidChangeNotification
                                             object:nil];
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
    return NSLocalizedString(@"Profile", @"[Technical] Title for profile analytics measurements");
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
    return [tableView dequeueReusableCellWithIdentifier:NSStringFromClass(ProfileTableViewCell.class) forIndexPath:indexPath];
}

#pragma mark UITableViewDelegate protocol

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 50.f;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(ProfileTableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    MenuItemInfo *menuItemInfo = self.sectionInfos[indexPath.section].menuItemInfos[indexPath.row];
    cell.menuItemInfo = menuItemInfo;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    MenuItemInfo *menuItemInfo = self.sectionInfos[indexPath.section].menuItemInfos[indexPath.row];
    [self openMenuItemInfo:menuItemInfo animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    MenuSectionInfo *sectionInfo = self.sectionInfos[section];
    return [ProfileHeaderSectionView heightForMenuSectionInfo:sectionInfo];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    ProfileHeaderSectionView *headerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:NSStringFromClass(ProfileHeaderSectionView.class)];
    headerView.menuSectionInfo = self.sectionInfos[section];
    return headerView;
}

#pragma mark Actions

- (void)openMenuItemInfo:(MenuItemInfo *)menuItemInfo animated:(BOOL)animated
{
    ApplicationConfiguration *applicationConfiguration = ApplicationConfiguration.sharedApplicationConfiguration;
    
    UIViewController *viewController = nil;
    switch (menuItemInfo.menuItem) {
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
            
        case MenuItemHistory: {
            viewController = [[HistoryViewController alloc] init];
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
            
        case MenuItemSettings: {
            viewController = [[SettingsViewController alloc] init];
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
    [self.tableView reloadData];
}

- (void)applicationConfigurationDidChange:(NSNotification *)notification
{
    self.sectionInfos = MenuSectionInfo.profileMenuSectionInfos;
    [self.tableView reloadData];
    
    // Do not update selectedMenuItemInfo. If now invalid, it must not be visibly selected after all. A correct value
    // will be set the next time the user selects a menu item
}

@end
