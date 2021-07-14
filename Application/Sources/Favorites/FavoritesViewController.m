//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "FavoritesViewController.h"

#import "AnalyticsConstants.h"
#import "ApplicationConfiguration.h"
#import "ApplicationSection.h"
#import "NSArray+PlaySRG.h"
#import "NSBundle+PlaySRG.h"
#import "PlaySRG-Swift.h"
#import "Favorites.h"
#import "Layout.h"
#import "RefreshControl.h"
#import "TableView.h"
#import "UIColor+PlaySRG.h"
#import "UIImageView+PlaySRG.h"
#import "UIViewController+PlaySRG.h"

@import libextobjc;
@import SRGAppearance;
@import SRGDataProvider;
@import SRGUserData;

@interface FavoritesViewController ()

@property (nonatomic) NSArray<SRGShow *> *shows;

@property (nonatomic, weak) TableView *tableView;
@property (nonatomic, weak) RefreshControl *refreshControl;

@property (nonatomic) UIImageView *loadingImageView;        // strong

@property (nonatomic) UIBarButtonItem *defaultLeftBarButtonItem;

@property (nonatomic) NSError *lastRequestError;
@property (nonatomic) NSArray<SRGShow *> *requestedShows;

@end

@implementation FavoritesViewController

#pragma mark Getters and setters

- (NSString *)title
{
    return TitleForApplicationSection(ApplicationSectionFavorites);
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
    
    [self.tableView registerReusableShowCell];
    
    // DZNEmptyDataSet stretches custom views horizontally. Ensure the image stays centered and does not get
    // stretched
    self.loadingImageView = [UIImageView play_largeLoadingImageViewWithTintColor:UIColor.srg_grayC7Color];
    self.loadingImageView.contentMode = UIViewContentModeCenter;
    
    [self updateInterfaceForEditionAnimated:NO];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(preferencesStateDidChange:)
                                               name:SRGPreferencesDidChangeNotification
                                             object:SRGUserData.currentUserData.preferences];
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

- (void)prepareRefreshWithRequestQueue:(SRGRequestQueue *)requestQueue
{
    self.requestedShows = [NSArray array];
    
    NSArray<NSString *> *showURNs = FavoritesShowURNs().array;
    NSUInteger pageSize = ApplicationConfiguration.sharedApplicationConfiguration.pageSize;
    
    __block SRGFirstPageRequest *firstRequest = nil;
    
    @weakify(self)
    firstRequest = [[SRGDataProvider.currentDataProvider showsWithURNs:showURNs completionBlock:^(NSArray<SRGShow *> * _Nullable shows, SRGPage * _Nonnull page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        @strongify(self)
        
        if (error) {
            [requestQueue reportError:error];
            return;
        }
        
        self.requestedShows = [self.requestedShows arrayByAddingObjectsFromArray:shows];
        if (nextPage) {
            SRGPageRequest *nextRequest = [firstRequest requestWithPage:nextPage];
            [requestQueue addRequest:nextRequest resume:YES];
        }
        else {
            firstRequest = nil;
        }
    }] requestWithPageSize:pageSize];
    [requestQueue addRequest:firstRequest resume:YES];
}

- (void)refreshDidStart
{
    self.lastRequestError = nil;
}

- (void)refreshDidFinishWithError:(NSError *)error
{
    self.lastRequestError = error;
    
    if (! error) {
        NSSortDescriptor *titleSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGShow.new, title) ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
        NSSortDescriptor *transmissionSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGShow.new, transmission) ascending:YES];
        self.shows = [self.requestedShows sortedArrayUsingDescriptors:@[titleSortDescriptor, transmissionSortDescriptor]];
    }
    self.requestedShows = nil;
    
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
    if (self.shows.count != 0) {
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
    return LayoutTableViewPaddingContentInsets;
}

#pragma mark DZNEmptyDataSetSource protocol

- (UIView *)customViewForEmptyDataSet:(UIScrollView *)scrollView
{
    if (self.loading) {
        return self.loadingImageView;
    }
    else {
        return nil;
    }
}

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView
{
    // Remark: No test for self.loading since a custom view is used in such cases
    NSDictionary<NSAttributedStringKey, id> *attributes = @{ NSFontAttributeName : [SRGFont fontWithStyle:SRGFontStyleH2],
                                                             NSForegroundColorAttributeName : UIColor.srg_grayC7Color };
    
    if (self.lastRequestError) {
        // Multiple errors. Pick the first ones
        NSError *error = self.lastRequestError;
        if ([error.domain isEqualToString:SRGNetworkErrorDomain] && error.code == SRGNetworkErrorMultiple) {
            error = [error.userInfo[SRGNetworkErrorsKey] firstObject];
        }
        return [[NSAttributedString alloc] initWithString:error.localizedDescription
                                               attributes:attributes];
    }
    else {
        return [[NSAttributedString alloc] initWithString:NSLocalizedString(@"No favorites", @"Text displayed when no favorites are available")
                                               attributes:attributes];
    }
}

- (NSAttributedString *)descriptionForEmptyDataSet:(UIScrollView *)scrollView
{
    // Remark: No test for self.loading since a custom view is used in such cases
    NSDictionary<NSAttributedStringKey, id> *attributes = @{ NSFontAttributeName : [SRGFont fontWithStyle:SRGFontStyleH4],
                                                             NSForegroundColorAttributeName : UIColor.srg_grayC7Color };
    
    if (self.lastRequestError) {
        return [[NSAttributedString alloc] initWithString:NSLocalizedString(@"Pull to reload", @"Text displayed to inform the user she can pull a list to reload it")
                                               attributes:attributes];
    }
    else {
        NSString *description = (self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable) ? NSLocalizedString(@"You can press on an item to add it to favorites", @"Hint displayed when no favorites are available and the device supports 3D touch") : NSLocalizedString(@"You can tap and hold an item to add it to favorites", @"Hint displayed when no favorites are available and the device does not support 3D touch");
        return [[NSAttributedString alloc] initWithString:description
                                               attributes:attributes];
    }
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView
{
    // Remark: No test for self.loading since a custom view is used in such cases
    if (self.lastRequestError) {
        return [UIImage imageNamed:@"error-background"];
    }
    else {
        return [UIImage imageNamed:@"favorite-background"];
    }
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
    return AnalyticsPageTitleFavorites;
}

- (NSArray<NSString *> *)srg_pageViewLevels
{
    return @[ AnalyticsPageLevelPlay, AnalyticsPageLevelUser ];
}

#pragma mark UITableViewDataSource protocol

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.shows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [tableView dequeueReusableShowCellFor:indexPath];
}

#pragma mark UITableViewDelegate protocol

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [[ShowCellSize fullWidth] constrainedBy:tableView].height + LayoutMargin;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell<ShowSettable> *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.show = self.shows[indexPath.row];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView.editing) {
        return;
    }
    
    SRGShow *show = self.shows[indexPath.row];
    SectionViewController *showViewController = [SectionViewController showViewControllerFor:show];
    [self.navigationController pushViewController:showViewController animated:YES];
    
    SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
    labels.value = show.URN;
    [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleFavoriteOpen labels:labels];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:nil handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        SRGShow *show = self.shows[indexPath.row];
        FavoritesRemoveShows(@[show]);
        [self updateInterfaceForEditionAnimated:YES];
        
        SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
        labels.value = show.URN;
        labels.source = AnalyticsSourceSwipe;
        [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleFavoriteRemove labels:labels];
        
        completionHandler(YES);
    }];
    deleteAction.image = [UIImage imageNamed:@"delete"];
    return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point
{
    return [ContextMenuObjC configurationFor:self.shows[indexPath.row] at:indexPath in:self];
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

- (void)removeSubscriptions:(id)sender
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
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Delete favorites", @"Title of the confirmation pop-up displayed when the user is about to delete favorite items")
                                                                             message:deleteAllModeEnabled ? NSLocalizedString(@"All items will be deleted.", @"Confirmation message displayed when the user is about to delete all favorites") : NSLocalizedString(@"The selected items will be deleted.", @"Confirmation message displayed when the user is about to delete selected entries from favorites")
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
        // Avoid issues if the user switches off notifications while the alert is displayed
        NSArray *selectedRows = self.tableView.indexPathsForSelectedRows;
        if (deleteAllModeEnabled || selectedRows.count == self.shows.count) {
            FavoritesRemoveShows(nil);
            
            self.shows = nil;
            [self reloadDataAnimated:YES];
            
            SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
            labels.source = AnalyticsSourceSelection;
            [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleFavoriteRemoveAll labels:labels];
        }
        else {
            NSMutableArray<SRGShow *> *showsToRemove = [NSMutableArray array];
            for (NSIndexPath *selectedIndexPath in selectedRows) {
                [showsToRemove addObject:self.shows[selectedIndexPath.row]];
            }
            
            FavoritesRemoveShows(showsToRemove.copy);
            
            for (SRGShow *show in showsToRemove) {
                SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
                labels.value = show.URN;
                labels.source = AnalyticsSourceSelection;
                [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleFavoriteRemove labels:labels];
            }
        }
        
        if (self.tableView.isEditing) {
            [self setEditing:NO animated:YES];
        }
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
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
                                                                           action:@selector(removeSubscriptions:)];
    deleteBarButtonItem.accessibilityLabel = PlaySRGAccessibilityLocalizedString(@"Delete", @"Delete button label");
    
    UIBarButtonItem *leftBarButtonItem = editing ? deleteBarButtonItem : self.defaultLeftBarButtonItem;
    if (editing) {
        leftBarButtonItem.tintColor = UIColor.redColor;
    }
    [self.navigationItem setLeftBarButtonItem:leftBarButtonItem animated:animated];
    
    [self updateInterfaceForEditionAnimated:animated];
}

#pragma mark Notifications

- (void)preferencesStateDidChange:(NSNotification *)notification
{
    // Update the URN list. Unlike other media / shows list, there is no pagination in this one. A simple refresh is accepted.
    NSSet<NSString *> *domains = notification.userInfo[SRGPreferencesDomainsKey];
    if ([domains containsObject:PlayPreferencesDomain]) {
        [self refresh];
    }
}

@end
