//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "NotificationsViewController.h"

#import "Banner.h"
#import "NSArray+PlaySRG.h"
#import "Notification.h"
#import "Play-Swift-Bridge.h"
#import "PlayErrors.h"
#import "PushService.h"
#import "ShowViewController.h"
#import "UIColor+PlaySRG.h"
#import "UIViewController+PlaySRG.h"

#import <SRGAppearance/SRGAppearance.h>

@interface NotificationsViewController ()

@property (nonatomic) NSArray<Notification *> *notifications;

@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, weak) UIRefreshControl *refreshControl;

@end

@implementation NotificationsViewController

#pragma mark Object lifecycle

- (instancetype)init
{
    if (self = [super init]) {
        self.notifications = Notification.notifications;
    }
    return self;
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"Notifications", @"Title displayed at the top of the notifications screen");
    
    self.view.backgroundColor = UIColor.play_blackColor;
    
    self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    
    self.tableView.emptyDataSetSource = self;
    self.tableView.emptyDataSetDelegate = self;
    
    NSString *cellIdentifier = NSStringFromClass(NotificationTableViewCell.class);
    UINib *cellNib = [UINib nibWithNibName:cellIdentifier bundle:nil];
    [self.tableView registerNib:cellNib forCellReuseIdentifier:cellIdentifier];
    
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    refreshControl.tintColor = UIColor.whiteColor;
    [refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    [self.tableView insertSubview:refreshControl atIndex:0];
    self.refreshControl = refreshControl;
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Close", @"Close button title")
                                                                              style:UIBarButtonItemStyleDone
                                                                             target:self
                                                                             action:@selector(close:)];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(applicationDidBecomeActive:)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(applicationWillResignActive:)
                                               name:UIApplicationWillResignActiveNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didReceiveNotification:)
                                               name:PushServiceDidReceiveNotification
                                             object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [PushService.sharedService resetApplicationBadge];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if ([self play_isMovingFromParentViewController]) {
        [PushService.sharedService resetApplicationBadge];
    }
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    // Force a layout update for the empty view to that it takes into account updated content insets appropriately.
    [self.tableView reloadEmptyDataSet];
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

#pragma mark Overrides

- (void)refresh
{
    // Avoid stopping scrolling
    // See http://stackoverflow.com/a/31681037/760435
    if (self.refreshControl.refreshing) {
        [self.refreshControl endRefreshing];
    }
    
    NSArray<Notification *> *notifications = Notification.notifications;
    [self.tableView reloadDataAnimatedWithOldObjects:self.notifications newObjects:notifications section:0 updateData:^{
        self.notifications = notifications;
    } completion:^(BOOL finished) {
        [self.tableView flashScrollIndicators];
    }];
}

- (AnalyticsPageType)pageType
{
    return AnalyticsPageTypeNotifications;
}

#pragma mark ContentInsets protocol

- (NSArray<UIScrollView *> *)play_contentScrollViews
{
    return self.tableView ? @[self.tableView] : nil;
}

- (UIEdgeInsets)play_paddingContentInsets
{
    return UIEdgeInsetsMake(5.f, 0.f, 10.f, 0.f);
}

#pragma mark DZNEmptyDataSetSource protocol

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView
{
    NSDictionary<NSAttributedStringKey, id> *attributes = @{ NSFontAttributeName : [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleTitle],
                                                             NSForegroundColorAttributeName : UIColor.play_lightGrayColor };
    return [[NSAttributedString alloc] initWithString:NSLocalizedString(@"No notifications", @"Text displayed when no notifications are available")
                                           attributes:attributes];
}

- (NSAttributedString *)descriptionForEmptyDataSet:(UIScrollView *)scrollView
{
    NSDictionary<NSAttributedStringKey, id> *attributes = @{ NSFontAttributeName : [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleSubtitle],
                                                             NSForegroundColorAttributeName : UIColor.play_lightGrayColor };
    return [[NSAttributedString alloc] initWithString:NSLocalizedString(@"Subscribe to shows you like to be notified when a new episode is available.", @"Message displayed when no notifications have been received")
                                           attributes:attributes];
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView
{
    return [UIImage imageNamed:@"subscription-90"];
}

- (UIColor *)imageTintColorForEmptyDataSet:(UIScrollView *)scrollView
{
    return UIColor.play_lightGrayColor;
}

- (BOOL)emptyDataSetShouldAllowScroll:(UIScrollView *)scrollView
{
    return YES;
}

- (CGFloat)verticalOffsetForEmptyDataSet:(UIScrollView *)scrollView
{
    return VerticalOffsetForEmptyDataSet(scrollView);
}

#pragma mark NotificationTableViewCellDelegate protocol

- (void)notificationTableViewCell:(NotificationTableViewCell *)cell willDeleteNotification:(Notification *)notification
{
    NSInteger index = [self.notifications indexOfObject:notification];
    if (index != NSNotFound) {
        self.notifications = [self.notifications play_arrayByRemovingObjectAtIndex:index];
        [self.tableView deleteRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:index inSection:0] ]
                              withRowAnimation:UITableViewRowAnimationAutomatic];
        [self.tableView reloadEmptyDataSet];
    }
}

#pragma mark UITableViewDataSource protocol

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.notifications.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [tableView dequeueReusableCellWithIdentifier:NSStringFromClass(NotificationTableViewCell.class) forIndexPath:indexPath];
}

#pragma mark UITableViewDelegate protocol

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *contentSizeCategory = UIApplication.sharedApplication.preferredContentSizeCategory;
    return (SRGAppearanceCompareContentSizeCategories(contentSizeCategory, UIContentSizeCategoryExtraLarge) == NSOrderedAscending) ? 94.f : 110.f;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(NotificationTableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.notification = self.notifications[indexPath.row];
    cell.cellDelegate = self;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    Notification *notification = self.notifications[indexPath.row];
    [Notification saveNotification:notification read:YES];
    
    if (notification.mediaURN) {
        [[SRGDataProvider.currentDataProvider mediaWithURN:notification.mediaURN completionBlock:^(SRGMedia * _Nullable media, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
            if (error) {
                [Banner showError:error inViewController:self];
                return;
            }
            
            [self play_presentMediaPlayerWithMedia:media position:nil fromPushNotification:NO animated:YES completion:^{
                SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
                labels.source = notification.showURN ?: AnalyticsSourceNotification;
                labels.type = NotificationTypeString(notification.type) ?: AnalyticsTypeActionPlayMedia;
                labels.value = notification.mediaURN;
                [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleNotificationOpen labels:labels];
            }];
        }] resume];
    }
    else if (notification.showURN) {
        [[SRGDataProvider.currentDataProvider showWithURN:notification.showURN completionBlock:^(SRGShow * _Nullable show, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
            if (error) {
                [Banner showError:error inViewController:self];
                return;
            }
            
            ShowViewController *showViewController = [[ShowViewController alloc] initWithShow:show fromPushNotification:NO];
            [self.navigationController pushViewController:showViewController animated:YES];
            
            SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
            labels.source = AnalyticsSourceNotification;
            labels.type = NotificationTypeString(notification.type) ?: AnalyticsTypeActionDisplayShow;
            labels.value = notification.showURN;
            [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleNotificationOpen labels:labels];
        }] resume];
    }
    else {
        SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
        labels.source = AnalyticsSourceNotification;
        labels.type = NotificationTypeString(notification.type) ?: AnalyticsTypeActionNotificationAlert;
        labels.value = notification.body;
        [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleNotificationOpen labels:labels];
    }
    
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark Actions

- (void)refresh:(id)sender
{
    [self refresh];
}

- (void)close:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark Notifications

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    if (self.viewVisible) {
        [PushService.sharedService resetApplicationBadge];
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
    [self refresh];
}

@end
