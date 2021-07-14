//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "TableRequestViewController.h"

#import "Banner.h"
#import "PlaySRG-Swift.h"
#import "RefreshControl.h"
#import "TableLoadMoreFooterView.h"
#import "UIColor+PlaySRG.h"
#import "UIImageView+PlaySRG.h"
#import "UIScrollView+PlaySRG.h"

@import libextobjc;
@import SRGAppearance;

@interface TableRequestViewController ()

@property (nonatomic) NSError *lastRequestError;
@property (nonatomic, weak) RefreshControl *refreshControl;

@property (nonatomic) UIImageView *loadingImageView;        // strong

@property (nonatomic) NSArray *previouslySelectedItems;

@end

@implementation TableRequestViewController

@synthesize emptyTableTitle = _emptyTableTitle;
@synthesize emptyTableSubtitle = _emptyTableSubtitle;

#pragma mark Getters and setters

- (NSString *)emptyTableTitle
{
    return _emptyTableTitle ? _emptyTableTitle : NSLocalizedString(@"No results", @"Default text displayed when no results are available");
}

- (NSString *)emptyTableSubtitle
{
    if (_emptyTableSubtitle) {
        return _emptyTableSubtitle;
    }
    else {
        return NSLocalizedString(@"Pull to reload", @"Text displayed to inform the user she can pull a list to reload it");
    }
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    
    self.tableView.emptyDataSetSource = self;
    self.tableView.emptyDataSetDelegate = self;
    
    NSString *footerIdentifier = NSStringFromClass(TableLoadMoreFooterView.class);
    UINib *footerNib = [UINib nibWithNibName:footerIdentifier bundle:nil];
    [self.tableView registerNib:footerNib forHeaderFooterViewReuseIdentifier:footerIdentifier];
    
    RefreshControl *refreshControl = [[RefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(tableRequestViewController_refresh:) forControlEvents:UIControlEventValueChanged];
    [self.tableView insertSubview:refreshControl atIndex:0];
    self.refreshControl = refreshControl;
    
    // DZNEmptyDataSet stretches custom views horizontally. Ensure the image stays centered and does not get
    // stretched
    self.loadingImageView = [UIImageView play_largeLoadingImageViewWithTintColor:UIColor.srg_grayC7Color];
    self.loadingImageView.contentMode = UIViewContentModeCenter;
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    // Force a layout update for the empty view to that it takes into account updated content insets appropriately.
    [self.tableView reloadEmptyDataSet];
}

#pragma mark Accessibility

- (void)updateForContentSizeCategory
{
    [super updateForContentSizeCategory];
    
    [self reloadData];
}

#pragma mark Request lifecycle

- (void)refreshDidStart
{
    self.lastRequestError = nil;
    self.previouslySelectedItems = [self itemsAtIndexPaths:self.tableView.indexPathsForSelectedRows];
    
    [self.tableView reloadEmptyDataSet];
}

- (void)refreshDidFinishWithError:(NSError *)error
{
    self.lastRequestError = error;
    [self endRefreshing];
    
    if (! error) {
        [self reloadData];
        
        [self selectItems:self.previouslySelectedItems];
        self.previouslySelectedItems = nil;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView flashScrollIndicators];
        });
    }
    // Display errors in the view background when the list is empty. When content has been loaded, we don't bother
    // the user with errors
    else if (self.items.count == 0) {
        [self.tableView reloadEmptyDataSet];
    }
    
    // Returns immediately to the top when the list is empty
    if (self.items.count == 0) {
        [self.tableView play_scrollToTopAnimated:NO];
    }
}

- (void)didCancelRefreshRequest
{
    [super didCancelRefreshRequest];
    
    [self endRefreshing];
}

#pragma mark UI

- (void)reloadData
{
    [self.tableView reloadData];
    
    if (self.canLoadMoreItems) {
        self.tableView.tableFooterView = [[TableLoadMoreFooterView alloc] initWithFrame:CGRectMake(0.f, 0.f, 0.f, 60.f)];
        
        // Automatically load pages while the footer is still visible (e.g. for small page sizes).
        if (CGRectGetMinY(self.tableView.tableFooterView.frame) < CGRectGetHeight(self.tableView.frame)) {
            [self loadNextPage];
        }
    }
    else {
        self.tableView.tableFooterView = nil;
    }
}

- (void)endRefreshing
{
    // Avoid stopping scrolling
    // See http://stackoverflow.com/a/31681037/760435
    if (self.refreshControl.refreshing) {
        [self.refreshControl endRefreshing];
    }
}

#pragma mark Overrides

- (void)hideItems:(NSArray *)items
{
    NSMutableArray<NSIndexPath *> *indexPaths = [NSMutableArray array];
    for (id item in items) {
        NSInteger itemIndex = [self.items indexOfObject:item];
        if (itemIndex != NSNotFound) {
            [indexPaths addObject:[NSIndexPath indexPathForRow:itemIndex inSection:0]];
        }
    }
    
    [super hideItems:items];
    
    [self.tableView deleteRowsAtIndexPaths:indexPaths.copy
                          withRowAnimation:UITableViewRowAnimationAutomatic];
    
    [self.tableView reloadEmptyDataSet];
}

#pragma mark Helpers

- (NSArray *)itemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    NSMutableArray *items = [NSMutableArray array];
    [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath * _Nonnull indexPath, NSUInteger idx, BOOL * _Nonnull stop) {
        [items addObject:self.items[indexPath.row]];
    }];
    return items.copy;
}

- (void)selectItems:(NSArray *)items
{
    [items enumerateObjectsUsingBlock:^(id _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
        NSUInteger index = [self.items indexOfObject:item];
        if (index == NSNotFound) {
            return;
        }
        
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
        [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
    }];
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
    NSDictionary *attributes = @{ NSFontAttributeName : [SRGFont fontWithStyle:SRGFontStyleH2],
                                  NSForegroundColorAttributeName : UIColor.srg_grayC7Color };
    
    if (self.lastRequestError) {
        // Multiple errors. Pick the first ones
        NSError *error = self.lastRequestError;
        if ([error.domain isEqualToString:SRGNetworkErrorDomain] && error.code == SRGNetworkErrorMultiple) {
            error = [error.userInfo[SRGNetworkErrorsKey] firstObject];
        }
        return [[NSAttributedString alloc] initWithString:error.localizedDescription attributes:attributes];
    }
    else {
        return [[NSAttributedString alloc] initWithString:self.emptyTableTitle attributes:attributes];
    }
}

- (NSAttributedString *)descriptionForEmptyDataSet:(UIScrollView *)scrollView
{
    // Remark: No test for self.loading since a custom view is used in such cases
    NSString *description = (self.lastRequestError == nil) ? self.emptyTableSubtitle : NSLocalizedString(@"Pull to reload", @"Text displayed to inform the user she can pull a list to reload it");
    if (description) {
        return [[NSAttributedString alloc] initWithString:description
                                               attributes:@{ NSFontAttributeName : [SRGFont fontWithStyle:SRGFontStyleH4],
                                                             NSForegroundColorAttributeName : UIColor.srg_grayC7Color }];
    }
    else {
        return nil;
    }
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView
{
    // Remark: No test for self.loading since a custom view is used in such cases. An error image is only displayed
    // when an empty image has been set (so that the empty layout always has images or not)
    if (self.lastRequestError && self.emptyCollectionImage) {
        return [UIImage imageNamed:@"error-background"];
    }
    else {
        return self.emptyCollectionImage;
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

#pragma mark TabBarActionable protocol

- (void)performActiveTabActionAnimated:(BOOL)animated
{
    [self.tableView play_scrollToTopAnimated:animated];
}

#pragma mark UITableViewDataSource protocol

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    [self doesNotRecognizeSelector:_cmd];
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self doesNotRecognizeSelector:_cmd];
    return UITableViewCell.new;
}

#pragma mark UITableViewDelegate protocol

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point
{
    return [ContextMenuObjC configurationFor:self.items[indexPath.row] at:indexPath in:self];
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

#pragma mark UIScrollViewDelegate protocol

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    // Start loading the next page when less than a few screen heights from the bottom
    static const NSInteger kNumberOfScreens = 4;
    if (! self.loading && ! self.lastRequestError
            && scrollView.contentOffset.y > scrollView.contentSize.height - kNumberOfScreens * CGRectGetHeight(scrollView.frame)) {
        [self loadNextPage];
    }
}

#pragma mark Actions

- (void)tableRequestViewController_refresh:(id)sender
{
    [self refresh];
}

@end
