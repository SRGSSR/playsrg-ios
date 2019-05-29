//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "DownloadsViewController.h"

#import "AnalyticsConstants.h"
#import "Banner.h"
#import "Download.h"
#import "DownloadFooterSectionView.h"
#import "DownloadTableViewCell.h"
#import "NSBundle+PlaySRG.h"
#import "Play-Swift-Bridge.h"
#import "PlayErrors.h"
#import "UIColor+PlaySRG.h"
#import "UIViewController+PlaySRG.h"

#import <libextobjc/libextobjc.h>
#import <SRGAnalytics/SRGAnalytics.h>
#import <SRGAppearance/SRGAppearance.h>

@interface DownloadsViewController ()

@property (nonatomic) NSArray<Download *> *downloads;

@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, weak) UIRefreshControl *refreshControl;

@property (nonatomic) UIBarButtonItem *defaultLeftBarButtonItem;

@end

@implementation DownloadsViewController

#pragma mark Object lifecycle

- (instancetype)init
{
    if (self = [super init]) {
        self.downloads = Download.downloads;
    }
    return self;
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"Downloads", @"Title displayed at the top of the downloads screen");
    
    self.view.backgroundColor = UIColor.play_blackColor;
    
    self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.allowsSelectionDuringEditing = YES;
    self.tableView.allowsMultipleSelectionDuringEditing = YES;
    
    self.tableView.emptyDataSetSource = self;
    self.tableView.emptyDataSetDelegate = self;
    
    NSString *cellIdentifier = NSStringFromClass(DownloadTableViewCell.class);
    UINib *cellNib = [UINib nibWithNibName:cellIdentifier bundle:nil];
    [self.tableView registerNib:cellNib forCellReuseIdentifier:cellIdentifier];
    
    NSString *footerIdentifier = NSStringFromClass(DownloadFooterSectionView.class);
    [self.tableView registerNib:[UINib nibWithNibName:footerIdentifier bundle:nil] forHeaderFooterViewReuseIdentifier:footerIdentifier];
    self.tableView.estimatedSectionFooterHeight = 40.f;
    
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    refreshControl.tintColor = UIColor.whiteColor;
    [refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    [self.tableView insertSubview:refreshControl atIndex:0];
    self.refreshControl = refreshControl;
    
    [self updateInterfaceForEditionAnimated:NO];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(downloadStateDidChange:)
                                               name:DownloadStateDidChangeNotification
                                             object:nil];
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
    
    [self.tableView reloadDataAnimatedWithOldObjects:self.downloads newObjects:Download.downloads updateData:^{
        self.downloads = Download.downloads;
    } completion:^(BOOL finished) {
        [self.tableView flashScrollIndicators];
    }];
}

- (AnalyticsPageType)pageType
{
    return AnalyticsPageTypeDownloads;
}

#pragma mark UI

- (void)updateInterfaceForEditionAnimated:(BOOL)animated
{
    if (self.downloads.count != 0) {
        UIBarButtonItem *rightBarButtonItem = ! self.tableView.editing ? self.editButtonItem : [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel", @"Title of a cancel button")
                                                                                                                                style:UIBarButtonItemStylePlain
                                                                                                                               target:self
                                                                                                                               action:@selector(toggleEdition:)];
        [self.navigationItem setRightBarButtonItem:rightBarButtonItem animated:animated];
    }
    else {
        [self.navigationItem setRightBarButtonItem:nil animated:animated];
    }
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
    NSDictionary *attributes = @{ NSFontAttributeName : [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleTitle],
                                  NSForegroundColorAttributeName : UIColor.play_lightGrayColor };
    return [[NSAttributedString alloc] initWithString:NSLocalizedString(@"No downloads", @"Text displayed when no downloads are available") attributes:attributes];
}

- (NSAttributedString *)descriptionForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *description = (self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable) ? NSLocalizedString(@"You can press on an item to download it (not all items can be downloaded)", @"Hint displayed when no downloads are available and the device supports 3D touch") : NSLocalizedString(@"You can tap and hold an item to download it (not all items can be downloaded)", @"Hint displayed when no downloads are available and the device does not support 3D touch");
    return [[NSAttributedString alloc] initWithString:description
                                           attributes:@{ NSFontAttributeName : [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleSubtitle],
                                                         NSForegroundColorAttributeName : UIColor.play_lightGrayColor }];
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView
{
    return [UIImage imageNamed:@"download-90"];
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

#pragma mark UITableViewDataSource protocol

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.downloads.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [tableView dequeueReusableCellWithIdentifier:NSStringFromClass(DownloadTableViewCell.class) forIndexPath:indexPath];
}

#pragma mark UITableViewDelegate protocol

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *contentSizeCategory = UIApplication.sharedApplication.preferredContentSizeCategory;
    return (SRGAppearanceCompareContentSizeCategories(contentSizeCategory, UIContentSizeCategoryExtraLarge) == NSOrderedAscending) ? 94.f : 110.f;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(DownloadTableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.download = self.downloads[indexPath.row];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView.editing) {
        return;
    }
    
    Download *download = self.downloads[indexPath.row];
    if (download.media) {
        [self play_presentMediaPlayerWithMedia:download.media position:nil fromPushNotification:NO animated:YES completion:nil];
        
        SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
        labels.value = download.URN;
        [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleDownloadOpenMedia labels:labels];
    }
    else if (download.state == DownloadStateDownloading) {
        [Banner showWithStyle:BannerStyleInfo
                      message:NSLocalizedString(@"Media is being downloaded", @"Message on top screen when trying to open a media in the download list and the media is being downloaded.")
                        image:nil
                       sticky:NO
             inViewController:self];
    }
    else {
        NSError *error = [NSError errorWithDomain:PlayErrorDomain code:PlayErrorCodeNotFound localizedDescription:NSLocalizedString(@"Media not available yet", @"Message on top screen when trying to open a media in the download list and the media is not downloaded.")];
        [Banner showError:error inViewController:self];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return UITableViewAutomaticDimension + 40.f;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    DownloadFooterSectionView *footerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:NSStringFromClass(DownloadFooterSectionView.class)];
    return footerView;
}

#pragma mark Actions

- (void)refresh:(id)sender
{
    [self refresh];
}

- (void)removeDownloads:(id)sender
{
    NSArray *selectedRows = self.tableView.indexPathsForSelectedRows;
    
    // Tapping on the delete button without selecting a row is a shortcut to delete all items
    BOOL deleteAllModeEnabled = (selectedRows.count == 0);
    if (deleteAllModeEnabled) {
        for (NSInteger section = 0; section < self.tableView.numberOfSections; section++) {
            for (NSInteger row = 0; row < [self.tableView numberOfRowsInSection:section]; row++) {
                [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section]
                                            animated:YES
                                      scrollPosition:UITableViewScrollPositionNone];
            }
        }
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:deleteAllModeEnabled ? NSLocalizedString(@"Remove all downloads", @"Title of the confirmation pop-up displayed when the user is about to delete all download items") : NSLocalizedString(@"Remove downloads", @"Title of the confirmation pop-up displayed when the user is about to delete selected download items")
                                                                             message:deleteAllModeEnabled ? NSLocalizedString(@"Are you sure you want to delete all items?", @"Confirmation message displayed when the user is about to delete all download items") : NSLocalizedString(@"Are you sure you want to delete the selected items?", @"Confirmation message displayed when the user is about to delete selected download items")
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Title of a cancel button") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (deleteAllModeEnabled) {
            for (NSInteger section = 0; section < self.tableView.numberOfSections; section++) {
                for (NSInteger row = 0; row < [self.tableView numberOfRowsInSection:section]; row++) {
                    [self.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section] animated:YES];
                }
            }
        }
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Delete", @"Title of a delete button") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        NSArray *selectedRows = self.tableView.indexPathsForSelectedRows;
        if (deleteAllModeEnabled || selectedRows.count == self.downloads.count) {
            [Download removeAllDownloads];
            
            SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
            labels.source = AnalyticsSourceSelection;
            [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleDownloadRemoveAll labels:labels];
        }
        else {
            NSMutableArray<Download *> *downloadsToRemove = [NSMutableArray array];
            for (NSIndexPath *selectedIndexPath in selectedRows) {
                [downloadsToRemove addObject:self.downloads[selectedIndexPath.row]];
            }
            
            for (Download *download in downloadsToRemove) {
                [Download removeDownload:download];
                
                SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
                labels.value = download.URN;
                labels.source = AnalyticsSourceSelection;
                [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleDownloadRemove labels:labels];
            }
        }
        
        if (self.tableView.isEditing) {
            [self setEditing:NO animated:YES];
        }
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (IBAction)toggleEdition:(id)sender
{
    BOOL editing = !self.tableView.isEditing;
    [self setEditing:editing animated:YES];
}

#pragma mark Edit mode

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    [self.tableView setEditing:editing animated:animated];
    
    if (editing) {
        self.defaultLeftBarButtonItem = self.navigationItem.leftBarButtonItem;
    }
    
    UIBarButtonItem *deleteBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"delete-22"]
                                                                            style:UIBarButtonItemStylePlain
                                                                           target:self
                                                                           action:@selector(removeDownloads:)];
    deleteBarButtonItem.accessibilityLabel = PlaySRGAccessibilityLocalizedString(@"Delete", @"Delete button label");
    
    UIBarButtonItem *leftBarButtonItem = editing ? deleteBarButtonItem : self.defaultLeftBarButtonItem;
    if (editing) {
        leftBarButtonItem.tintColor = UIColor.redColor;
    }
    [self.navigationItem setLeftBarButtonItem:leftBarButtonItem animated:animated];
    
    [self updateInterfaceForEditionAnimated:animated];
}

#pragma mark Notifications

- (void)downloadStateDidChange:(NSNotification *)notification
{
    [self refresh];
}

@end
