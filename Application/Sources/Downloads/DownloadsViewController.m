//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "DownloadsViewController.h"

#import "AnalyticsConstants.h"
#import "ApplicationConfiguration.h"
#import "ApplicationSection.h"
#import "Banner.h"
#import "Download.h"
#import "DownloadFooterSectionView.h"
#import "DownloadTableViewCell.h"
#import "Layout.h"
#import "NSBundle+PlaySRG.h"
#import "PlayErrors.h"
#import "PlaySRG-Swift.h"
#import "RefreshControl.h"
#import "TableView.h"
#import "UIColor+PlaySRG.h"
#import "UIViewController+PlaySRG.h"

@import libextobjc;
@import SRGAnalytics;
@import SRGAppearance;

@interface DownloadsViewController ()

@property (nonatomic) NSArray<Download *> *downloads;

@property (nonatomic, weak) TableView *tableView;
@property (nonatomic, weak) RefreshControl *refreshControl;

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

#pragma mark Getters and setters

- (NSString *)title
{
    return TitleForApplicationSection(ApplicationSectionDownloads);
}

#pragma mark View lifecycle

- (void)loadView
{
    UIView *view = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    view.backgroundColor = UIColor.srg_gray16Color;
        
    TableView *tableView = [[TableView alloc] initWithFrame:view.bounds];
    tableView.allowsSelectionDuringEditing = YES;
    tableView.allowsMultipleSelectionDuringEditing = YES;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [view addSubview:tableView];
    self.tableView = tableView;
    
    RefreshControl *refreshControl = [[RefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    [tableView insertSubview:refreshControl atIndex:0];
    self.refreshControl = refreshControl;
    
    self.view = view;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    
    self.tableView.emptyDataSetSource = self;
    self.tableView.emptyDataSetDelegate = self;
    
    NSString *cellIdentifier = NSStringFromClass(DownloadTableViewCell.class);
    UINib *cellNib = [UINib nibWithNibName:cellIdentifier bundle:nil];
    [self.tableView registerNib:cellNib forCellReuseIdentifier:cellIdentifier];
    
    NSString *footerIdentifier = NSStringFromClass(DownloadFooterSectionView.class);
    [self.tableView registerNib:[UINib nibWithNibName:footerIdentifier bundle:nil] forHeaderFooterViewReuseIdentifier:footerIdentifier];
    
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
    
    [self reloadDataAnimated:NO];
}

#pragma mark Overrides

- (void)refresh
{
    // Avoid stopping scrolling
    // See http://stackoverflow.com/a/31681037/760435
    if (self.refreshControl.refreshing) {
        [self.refreshControl endRefreshing];
    }
    
    [self reloadDataAnimated:YES];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView flashScrollIndicators];
    });
}

#pragma mark UI

- (void)reloadDataAnimated:(BOOL)animated
{
    [self.tableView reloadData];
    [self updateInterfaceForEditionAnimated:animated];
}

- (void)updateInterfaceForEditionAnimated:(BOOL)animated
{
    if (self.downloads.count != 0) {
        [self.navigationItem setRightBarButtonItem:self.editButtonItem animated:animated];
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
    return LayoutPaddingContentInsets;
}

#pragma mark DZNEmptyDataSetSource protocol

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView
{
    NSDictionary *attributes = @{ NSFontAttributeName : [SRGFont fontWithStyle:SRGFontStyleH2],
                                  NSForegroundColorAttributeName : UIColor.srg_grayC7Color };
    return [[NSAttributedString alloc] initWithString:NSLocalizedString(@"No downloads", @"Text displayed when no downloads are available") attributes:attributes];
}

- (NSAttributedString *)descriptionForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *description = (self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable) ? NSLocalizedString(@"You can press on an item to download it (not all items can be downloaded)", @"Hint displayed when no downloads are available and the device supports 3D touch") : NSLocalizedString(@"You can tap and hold an item to download it (not all items can be downloaded)", @"Hint displayed when no downloads are available and the device does not support 3D touch");
    return [[NSAttributedString alloc] initWithString:description
                                           attributes:@{ NSFontAttributeName : [SRGFont fontWithStyle:SRGFontStyleSubtitle1],
                                                         NSForegroundColorAttributeName : UIColor.srg_grayC7Color }];
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView
{
    return [UIImage imageNamed:@"download-background"];
}

- (UIColor *)imageTintColorForEmptyDataSet:(UIScrollView *)scrollView
{
    return UIColor.srg_grayC7Color;
}

- (BOOL)emptyDataSetShouldAllowScroll:(UIScrollView *)scrollView
{
    return YES;
}

- (CGFloat)verticalOffsetForEmptyDataSet:(UIScrollView *)scrollView
{
    return VerticalOffsetForEmptyDataSet(scrollView);
}

#pragma mark SRGAnalyticsViewTracking protocol

- (NSString *)srg_pageViewTitle
{
    return AnalyticsPageTitleDownloads;
}

- (NSArray<NSString *> *)srg_pageViewLevels
{
    return @[ AnalyticsPageLevelPlay, AnalyticsPageLevelUser ];
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
    return [[MediaCellSize fullWidth] constrainedBy:tableView].height + LayoutMargin;
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
        [self play_presentMediaPlayerWithMedia:download.media position:nil airPlaySuggestions:YES fromPushNotification:NO animated:YES completion:nil];
        
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
        NSError *error = [NSError errorWithDomain:PlayErrorDomain
                                             code:PlayErrorCodeNotFound
                                         userInfo:@{ NSLocalizedDescriptionKey : NSLocalizedString(@"Media not available yet", @"Message on top screen when trying to open a media in the download list and the media is not downloaded.") }];
        [Banner showError:error inViewController:self];
    }
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:nil handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        Download *download = self.downloads[indexPath.row];
        [Download removeDownload:download];
        
        SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
        labels.value = download.URN;
        labels.source = AnalyticsSourceSwipe;
        [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleDownloadRemove labels:labels];
        
        completionHandler(YES);
    }];
    deleteAction.image = [UIImage imageNamed:@"delete"];
    return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return self.downloads.count != 0 ? 40.f : 0.f;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    return [tableView dequeueReusableHeaderFooterViewWithIdentifier:NSStringFromClass(DownloadFooterSectionView.class)];
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point
{
    return [ContextMenuObjC configurationFor:self.downloads[indexPath.row] at:indexPath in:self];
}

- (UITargetedPreview *)tableView:(UITableView *)tableView previewForHighlightingContextMenuWithConfiguration:(UIContextMenuConfiguration *)configuration
{
    return [self previewForConfiguration:configuration inTableView:tableView];
}

- (UITargetedPreview *)tableView:(UITableView *)tableView previewForDismissingContextMenuWithConfiguration:(UIContextMenuConfiguration *)configuration
{
    return [self previewForConfiguration:configuration inTableView:tableView];
}

- (UITargetedPreview *)previewForConfiguration:(UIContextMenuConfiguration *)configuration inTableView:(UITableView *)tableView
{
    UIView *interactionView = [ContextMenuObjC interactionViewInTableView:tableView with:configuration];
    if (! interactionView) {
        return nil;
    }
    
    UIPreviewParameters *parameters = [[UIPreviewParameters alloc] init];
    parameters.backgroundColor = self.view.backgroundColor;
    return [[UITargetedPreview alloc] initWithView:interactionView parameters:parameters];
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
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Delete downloads", @"Title of the confirmation pop-up displayed when the user is about to delete download items")
                                                                             message:deleteAllModeEnabled ? NSLocalizedString(@"All items will be deleted.", @"Confirmation message displayed when the user is about to delete all download items") : NSLocalizedString(@"The selected items will be deleted.", @"Confirmation message displayed when the user is about to delete selected download items")
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
            self.downloads = nil;
            [self reloadDataAnimated:YES];
            
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
    
    [self.tableView setEditing:NO animated:animated];
    [self.tableView setEditing:editing animated:animated];
    
    if (editing) {
        self.defaultLeftBarButtonItem = self.navigationItem.leftBarButtonItem;
        self.editButtonItem.title = NSLocalizedString(@"Cancel", @"Title of a cancel button");
    }
    
    UIBarButtonItem *deleteBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"delete"]
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
    Download *download = notification.object;
    DownloadState state = [notification.userInfo[DownloadStateKey] integerValue];
    
    switch (state) {
        case DownloadStateAdded:
        case DownloadStateRemoved: {
            BOOL added = (state == DownloadStateAdded);
            // We only receive 1 object in notification. Could have more change…
            if ((added && self.downloads.count + 1 == Download.downloads.count)
                    || (! added && self.downloads.count - 1 == Download.downloads.count)) {
                [self.tableView beginUpdates];
                if (added) {
                    self.downloads = Download.downloads;
                    NSInteger downloadIndex = [self.downloads indexOfObject:download];
                    [self.tableView insertRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:downloadIndex inSection:0] ]
                                          withRowAnimation:UITableViewRowAnimationAutomatic];
                }
                else {
                    NSInteger downloadIndex = [self.downloads indexOfObject:download];
                    self.downloads = Download.downloads;
                    [self.tableView deleteRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:downloadIndex inSection:0] ]
                                          withRowAnimation:UITableViewRowAnimationAutomatic];
                }
                [self.tableView endUpdates];
                
                [self updateInterfaceForEditionAnimated:YES];
            }
            else {
                self.downloads = Download.downloads;
                [self reloadDataAnimated:YES];
            }
            break;
        }
            
        default:
            break;
    }
}

@end
