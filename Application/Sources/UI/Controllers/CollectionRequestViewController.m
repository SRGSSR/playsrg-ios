//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "CollectionRequestViewController.h"

#import "Banner.h"
#import "CollectionLoadMoreFooterView.h"
#import "Play-Swift-Bridge.h"
#import "UIColor+PlaySRG.h"
#import "UIImageView+PlaySRG.h"

#import <libextobjc/libextobjc.h>
#import <SRGAppearance/SRGAppearance.h>

@interface CollectionRequestViewController ()

@property (nonatomic) NSError *lastRequestError;
@property (nonatomic, weak) UIRefreshControl *refreshControl;

@end

@implementation CollectionRequestViewController

@synthesize emptyCollectionTitle = _emptyCollectionTitle;
@synthesize emptyCollectionSubtitle = _emptyCollectionSubtitle;

#pragma mark Getters and setters

- (NSString *)emptyCollectionTitle
{
    return _emptyCollectionTitle ? _emptyCollectionTitle : NSLocalizedString(@"No results", @"Default text displayed when no results are available");
}

- (NSString *)emptyCollectionSubtitle
{
    if (_emptyCollectionSubtitle) {
        return _emptyCollectionSubtitle;
    }
    else {
        return NSLocalizedString(@"Pull to reload", @"Text displayed to inform the user she can pull a list to reload it");
    }
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSAssert([self.collectionView.collectionViewLayout isKindOfClass:UICollectionViewFlowLayout.class], @"This class requires a valid collection view with a flow layout");
    
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    
    self.collectionView.emptyDataSetSource = self;
    self.collectionView.emptyDataSetDelegate = self;
    
    NSString *footerIdentifier = NSStringFromClass(CollectionLoadMoreFooterView.class);
    UINib *footerNib = [UINib nibWithNibName:footerIdentifier bundle:nil];
    [self.collectionView registerNib:footerNib forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:footerIdentifier];
    
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    refreshControl.tintColor = UIColor.whiteColor;
    refreshControl.layer.zPosition = -1.f;          // Ensure the refresh control appears behind the cells, see http://stackoverflow.com/a/25829016/760435
    [refreshControl addTarget:self action:@selector(collectionRequestViewController_refresh:) forControlEvents:UIControlEventValueChanged];
    [self.collectionView insertSubview:refreshControl atIndex:0];
    self.refreshControl = refreshControl;
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    // Force a layout update for the empty view to that it takes into account updated content insets appropriately.
    // TODO: This might induce some minor font color glitches in somes cases (e.g. resizing in the calendar view), but at
    //       least this works properly from a layout point of view. The empty data set component should be updated to
    //       provide a way to update its layout without reloading it entirely, which is currently not the case and
    //       generates such gliches.
    [self.collectionView reloadEmptyDataSet];
}

#pragma mark Responsiveness

- (void)willTransitionToTraitCollection:(UITraitCollection *)newCollection withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super willTransitionToTraitCollection:newCollection withTransitionCoordinator:coordinator];
    
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> _Nonnull context) {
        [self.collectionView.collectionViewLayout invalidateLayout];
    }];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    
    [self.collectionView.collectionViewLayout invalidateLayout];
}

#pragma mark Accessibility

- (void)updateForContentSizeCategory
{
    [super updateForContentSizeCategory];
    
    [self.collectionView reloadData];
}

#pragma mark Request lifecycle

- (void)refreshDidStart
{
    self.lastRequestError = nil;
    
    [self.collectionView reloadEmptyDataSet];
    [self.collectionView.collectionViewLayout invalidateLayout];
}

- (void)refreshDidFinishWithError:(NSError *)error
{
    self.lastRequestError = error;
    [self endRefreshing];
}

- (void)didCancelRefreshRequest
{
    [super didCancelRefreshRequest];
    
    [self endRefreshing];
}

- (void)updateWithItems:(NSArray *)items previousItems:(NSArray *)previousItems completion:(void (NS_NOESCAPE ^)(void))completion
{
    [self.collectionView reloadDataAnimatedWithOldObjects:previousItems newObjects:items updateData:^{
        completion();
    } completion:^(BOOL finished) {
        [self.collectionView reloadEmptyDataSet];
        [self.collectionView flashScrollIndicators];
    }];
}

#pragma mark UI

- (void)endRefreshing
{
    // Avoid stopping scrolling
    // See http://stackoverflow.com/a/31681037/760435
    if (self.refreshControl.refreshing) {
        [self.refreshControl endRefreshing];
    }
}

#pragma mark ContentInsets protocol

- (NSArray<UIScrollView *> *)play_contentScrollViews
{
    return self.collectionView ? @[self.collectionView] : nil;
}

- (UIEdgeInsets)play_paddingContentInsets
{
    return UIEdgeInsetsZero;
}

#pragma mark DZNEmptyDataSetSource protocol

- (UIView *)customViewForEmptyDataSet:(UIScrollView *)scrollView
{
    if (self.loading) {
        // DZNEmptyDataSet stretches custom views horizontally. Ensure the image stays centered and does not get
        // stretched
        UIImageView *loadingImageView = [UIImageView play_loadingImageView90WithTintColor:UIColor.play_lightGrayColor];
        loadingImageView.contentMode = UIViewContentModeCenter;
        return loadingImageView;
    }
    else {
        return nil;
    }
}

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView
{
    // Remark: No test for self.loading since a custom view is used in such cases
    NSDictionary *attributes = @{ NSFontAttributeName : [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleTitle],
                                  NSForegroundColorAttributeName : UIColor.play_lightGrayColor };
    
    if (self.lastRequestError) {
        // Multiple errors. Pick the first ones
        NSError *error = self.lastRequestError;
        if ([error hasCode:SRGNetworkErrorMultiple withinDomain:SRGNetworkErrorDomain]) {
            error = [error.userInfo[SRGNetworkErrorsKey] firstObject];
        }
        return [[NSAttributedString alloc] initWithString:error.localizedDescription attributes:attributes];
    }
    else {
        return [[NSAttributedString alloc] initWithString:self.emptyCollectionTitle attributes:attributes];
    }
}

- (NSAttributedString *)descriptionForEmptyDataSet:(UIScrollView *)scrollView
{
    // Remark: No test for self.loading since a custom view is used in such cases
    NSString *description = (self.lastRequestError == nil) ? self.emptyCollectionSubtitle : NSLocalizedString(@"Pull to reload", @"Text displayed to inform the user she can pull a list to reload it");
    if (description) {
        return [[NSAttributedString alloc] initWithString:description
                                               attributes:@{ NSFontAttributeName : [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleSubtitle],
                                                             NSForegroundColorAttributeName : UIColor.play_lightGrayColor }];
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
        return [UIImage imageNamed:@"error-90"];
    }
    else {
        return self.emptyCollectionImage;
    }
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

#pragma mark UICollectionViewDataSource protocol

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    HLSMissingMethodImplementation();
    return 0;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    HLSMissingMethodImplementation();
    return [UICollectionViewCell new];
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    return [collectionView dequeueReusableSupplementaryViewOfKind:kind
                                              withReuseIdentifier:NSStringFromClass(CollectionLoadMoreFooterView.class)
                                                     forIndexPath:indexPath];
}

#pragma mark UICollectionViewDelegate protocol

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewFlowLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section
{
    NSInteger numberOfSections = collectionView.numberOfSections;
    
    // Only display a load more footer at the collection bottom if there is more content to load
    if (section == numberOfSections - 1 && self.canLoadMoreItems && !self.lastRequestError && [self shouldPerformRefreshRequest]) {
        return CGSizeMake(CGRectGetWidth(collectionView.frame) - collectionViewLayout.sectionInset.left - collectionViewLayout.sectionInset.right, 60.f);
    }
    else {
        return CGSizeZero;
    }
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

- (void)collectionRequestViewController_refresh:(id)sender
{
    [self refresh];
}

@end
