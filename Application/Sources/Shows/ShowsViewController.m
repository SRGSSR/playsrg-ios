//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "ShowsViewController.h"

#import "ApplicationConfiguration.h"
#import "PageViewController.h"
#import "ShowCollectionViewCell.h"
#import "ShowViewController.h"
#import "TranslucentTitleHeaderView.h"
#import "UIColor+PlaySRG.h"
#import "UIViewController+PlaySRG.h"

#import <BDKCollectionIndexView/BDKCollectionIndexView.h>
#import <libextobjc/libextobjc.h>
#import <Masonry/Masonry.h>
#import <SRGAppearance/SRGAppearance.h>

@interface ShowsViewController () {
@private
    NSInteger _previousAccessibilityHeadingSection;
}

@property (nonatomic) RadioChannel *radioChannel;

@property (nonatomic) NSArray<NSString *> *indexLetters;
@property (nonatomic) NSDictionary<NSString *, NSArray<SRGShow *> *> *showsAlphabeticalMap;

@property (nonatomic, weak) BDKCollectionIndexView *collectionIndexView;

@property (nonatomic) UISelectionFeedbackGenerator *selectionFeedbackGenerator API_AVAILABLE(ios(10.0));

@end

@implementation ShowsViewController

#pragma mark Object lifecycle

- (instancetype)initWithRadioChannel:(RadioChannel *)radioChannel
{
    if (self = [super init]) {
        self.radioChannel = radioChannel;
        
        if (@available(iOS 10, *)) {
            self.selectionFeedbackGenerator = [[UISelectionFeedbackGenerator alloc] init];      // Only available for iOS 10 and above
        }
        
        _previousAccessibilityHeadingSection = -1;
        
        if (self.radioChannel) {
            self.title = NSLocalizedString(@"Programmes A-Z", @"Title displayed at the top of a (radio) show list");
        }
        else {
            self.title = NSLocalizedString(@"TV programmes A-Z", @"Title displayed at the top of the TV show list");
        }
    }
    return self;
}

- (instancetype)init
{
    return [self initWithRadioChannel:nil];
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = UIColor.play_blackColor;
    
    self.emptyCollectionImage = [UIImage imageNamed:@"media-90"];
    
    self.collectionView.backgroundColor = UIColor.clearColor;
    self.collectionView.showsVerticalScrollIndicator = NO;      // As in Contacts, no need for scroll indicators when an index is displayed
    self.collectionView.alwaysBounceVertical = YES;
    
    UICollectionViewFlowLayout *collectionViewFlowLayout = (UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout;
    collectionViewFlowLayout.sectionHeadersPinToVisibleBounds = YES;
    
    NSString *cellIdentifier = NSStringFromClass(ShowCollectionViewCell.class);
    UINib *cellNib = [UINib nibWithNibName:cellIdentifier bundle:nil];
    [self.collectionView registerNib:cellNib forCellWithReuseIdentifier:cellIdentifier];
    
    NSString *headerIdentifier = NSStringFromClass(TranslucentTitleHeaderView.class);
    UINib *headerNib = [UINib nibWithNibName:headerIdentifier bundle:nil];
    [self.collectionView registerNib:headerNib forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:headerIdentifier];
    
    // BDKCollectionIndexView can only be instantiated in code ;(
    BDKCollectionIndexView *collectionIndexView = [[BDKCollectionIndexView alloc] initWithFrame:CGRectZero indexTitles:nil];
    collectionIndexView.tintColor = UIColor.play_lightGrayColor;
    [collectionIndexView addTarget:self action:@selector(collectionIndexChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:collectionIndexView];
    self.collectionIndexView = collectionIndexView;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // UICollectionView loads its content lazily and headers might therefore not visible and accessible when navigating
    // in headings accessibility mode. To solve this issue, we follow the focus and scroll the collection automatically
    // to reveal the last section item
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(accessibilityElementFocused:)
                                               name:UIAccessibilityElementFocusedNotification
                                             object:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [NSNotificationCenter.defaultCenter removeObserver:self
                                                  name:UIAccessibilityElementFocusedNotification
                                                object:nil];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    [self.collectionIndexView mas_updateConstraints:^(MASConstraintMaker *make) {
        if (@available(iOS 11, *)) {
            make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop).with.offset(self.play_pageViewController.play_additionalContentInsets.top);
            make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom);
        }
        else {
            UIEdgeInsets contentInsets = ContentInsetsForViewController(self);
            make.top.equalTo(self.view).with.offset(contentInsets.top);
            make.bottom.equalTo(self.view).with.offset(-contentInsets.bottom);
        }
        
        make.right.equalTo(self.collectionView.mas_right);
        make.width.equalTo(@28.f);
    }];
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

#pragma mark Overrides

- (void)prepareRefreshWithRequestQueue:(SRGRequestQueue *)requestQueue page:(SRGPage *)page completionHandler:(ListRequestPageCompletionHandler)completionHandler
{
    SRGVendor vendor = ApplicationConfiguration.sharedApplicationConfiguration.vendor;
    
    // Since we need to display the A-Z index, all shows need to be loaded. We therefore do not use the native page
    // support but load all the shows at once
    if (self.radioChannel) {
        SRGPageRequest *request = [[[SRGDataProvider.currentDataProvider radioShowsForVendor:vendor channelUid:self.radioChannel.uid withCompletionBlock:completionHandler] requestWithPageSize:SRGDataProviderUnlimitedPageSize] requestWithPage:page];
        [requestQueue addRequest:request resume:YES];
    }
    else {
        SRGPageRequest *request = [[[SRGDataProvider.currentDataProvider tvShowsForVendor:vendor withCompletionBlock:completionHandler] requestWithPageSize:SRGDataProviderUnlimitedPageSize] requestWithPage:page];
        [requestQueue addRequest:request resume:YES];
    }
}

- (void)updateWithItems:(NSArray *)items previousItems:(NSArray *)previousItems completion:(void (NS_NOESCAPE ^)(void))completion
{
    // Separate all shows according to their first letter (beware of special characters and emojis)
    NSMutableDictionary<NSString *, NSMutableArray<SRGShow *> *> *showsAlphabeticalMap = [NSMutableDictionary dictionary];
    [items enumerateObjectsUsingBlock:^(SRGShow *  _Nonnull show, NSUInteger idx, BOOL * _Nonnull stop) {
        NSMutableString *firstLetter = [[show.title substringToIndex:1].uppercaseString mutableCopy];
        if (! firstLetter) {
            return;
        }
        
        // Remove accents / diacritics and extract the first char (for wide chars / emoji support)
        CFStringTransform((__bridge CFMutableStringRef)firstLetter, NULL, kCFStringTransformStripCombiningMarks, NO);
        unichar firstChar = [firstLetter characterAtIndex:0];
        if (! isalpha(firstChar)) {
            firstChar = '#';
        }
        
        NSString *indexLetter = [NSString stringWithCharacters:&firstChar length:1];
        
        NSMutableArray *showsForIndexLetter = showsAlphabeticalMap[indexLetter];
        if (! showsForIndexLetter) {
            showsForIndexLetter = [NSMutableArray array];
            showsAlphabeticalMap[indexLetter] = showsForIndexLetter;
        }
        [showsForIndexLetter addObject:show];
    }];
    
    self.showsAlphabeticalMap = [showsAlphabeticalMap copy];
    self.indexLetters = [showsAlphabeticalMap.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    self.collectionIndexView.indexTitles = self.indexLetters;
    
    // Call last to continue with the reload process, based on the sorted data
    [super updateWithItems:items previousItems:previousItems completion:completion];
}

- (BOOL)srg_isTrackedAutomatically
{
    // Only tracked if standalone
    return ! self.play_pageViewController;
}

- (NSString *)srg_pageViewTitle
{
    return NSLocalizedString(@"Programmes A-Z", @"[Technical] Title for programmes A-Z page view analytics measurements");
}

- (AnalyticsPageType)pageType
{
    return self.radioChannel != nil ? AnalyticsPageTypeRadio : AnalyticsPageTypeTV;
}

#pragma mark UICollectionViewDataSource protocol

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return self.indexLetters.count;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    NSString *indexLetter = self.indexLetters[section];
    return self.showsAlphabeticalMap[indexLetter].count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [collectionView dequeueReusableCellWithReuseIdentifier:NSStringFromClass(ShowCollectionViewCell.class)
                                                     forIndexPath:indexPath];
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    if ([kind isEqualToString:UICollectionElementKindSectionHeader]) {
        return [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                                                  withReuseIdentifier:NSStringFromClass(TranslucentTitleHeaderView.class)
                                                         forIndexPath:indexPath];
    }
    else {
        return [super collectionView:collectionView viewForSupplementaryElementOfKind:kind atIndexPath:indexPath];
    }
}

#pragma mark UICollectionViewDelegate protocol

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(ShowCollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *indexLetter = self.indexLetters[indexPath.section];
    cell.show = self.showsAlphabeticalMap[indexLetter][indexPath.row];
}

- (void)collectionView:(UICollectionView *)collectionView willDisplaySupplementaryView:(UICollectionReusableView *)view forElementKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
    if ([view isKindOfClass:TranslucentTitleHeaderView.class]) {
        TranslucentTitleHeaderView *headerView = (TranslucentTitleHeaderView *)view;
        headerView.title = self.indexLetters[indexPath.section];
    }
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *indexLetter = self.indexLetters[indexPath.section];
    SRGShow *show = self.showsAlphabeticalMap[indexLetter][indexPath.row];
    
    ShowViewController *showViewController = [[ShowViewController alloc] initWithShow:show fromPushNotification:NO];
    [self.navigationController pushViewController:showViewController animated:YES];
}

#pragma mark UICollectionViewDelegateFlowLayout protocol

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewFlowLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    // 2 items per row on small layouts, max cell width of 210
    CGFloat width = fminf(floorf((CGRectGetWidth(collectionView.frame) - collectionViewLayout.sectionInset.left - collectionViewLayout.sectionInset.right - collectionViewLayout.minimumInteritemSpacing) / 2.f), 210.f);
    
    NSString *contentSizeCategory = UIApplication.sharedApplication.preferredContentSizeCategory;
    CGFloat minTextHeight = (SRGAppearanceCompareContentSizeCategories(contentSizeCategory, UIContentSizeCategoryExtraLarge) == NSOrderedAscending) ? 30.f : 50.f;
    
    return CGSizeMake(width, ceilf(width * 9.f / 16.f + minTextHeight));
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
    return CGSizeMake(CGRectGetWidth(collectionView.frame), 44.f);
}

#pragma mark Actions

- (IBAction)collectionIndexChanged:(id)sender
{
    NSAssert([sender isKindOfClass:BDKCollectionIndexView.class], @"Expect a collection index");
    
    if (@available(iOS 10, *)) {
        [self.selectionFeedbackGenerator selectionChanged];
    }
    
    BDKCollectionIndexView *collectionIndexView = sender;
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:collectionIndexView.currentIndex];
    
    // -scrollToItemAtIndexPath:atScrollPosition:animated: doesn't take care of the sticky section header and transparent navigation bar
    CGRect sectionHeaderFrame = [self.collectionView layoutAttributesForSupplementaryElementOfKind:UICollectionElementKindSectionHeader atIndexPath:indexPath].frame;
    CGRect itemFrame = [self.collectionView layoutAttributesForItemAtIndexPath:indexPath].frame;
    
    // FIXME: Incorrect behavior: When scrolling to the top or bottom of the index, the cell boundary should be exact. Behavior
    //        is incorrect at the bottom on < iOS 11 (also in production), incorrect at the top as well on iOS 11. We probably
    //        need to take insets into account correctly in all cases.
    CGFloat contentInsetTop = ContentInsetsForScrollView(self.collectionView).top;
    CGFloat sectionHeaderHeight = CGRectGetHeight(sectionHeaderFrame);
    CGFloat sectionInsetTop = ((UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout).sectionInset.top;
    CGFloat newContentOffsetY = fminf(CGRectGetMinY(itemFrame) - sectionHeaderHeight - sectionInsetTop - contentInsetTop,
                                      self.collectionView.contentSize.height - CGRectGetHeight(self.collectionView.frame));
    [self.collectionView setContentOffset:CGPointMake(self.collectionView.contentOffset.x, newContentOffsetY) animated:NO];
}

#pragma mark Notifications

- (void)accessibilityElementFocused:(NSNotification *)notification
{
    id element = notification.userInfo[UIAccessibilityFocusedElementKey];
    
    // Filter only focus notifications related to the receiver
    if ([element isKindOfClass:TranslucentTitleHeaderView.class] && [element isDescendantOfView:self.view]) {
        TranslucentTitleHeaderView *headerView = element;
        NSParameterAssert(headerView.title);
        
        NSInteger section = [self.indexLetters indexOfObject:headerView.title];
        
        NSIndexPath *indexPath = nil;
        
        // Moving downwards. Go to section end
        if (section > _previousAccessibilityHeadingSection) {
            NSUInteger numberOfItems = [self collectionView:self.collectionView numberOfItemsInSection:section];
            indexPath = [NSIndexPath indexPathForRow:numberOfItems - 1 inSection:section];
        }
        // Moving upwards. Go to section beginning
        else {
            indexPath = [NSIndexPath indexPathForRow:0 inSection:section];
        }
        
        _previousAccessibilityHeadingSection = section;
        
        // Center the item (works in both directions, and top or bottom would potentially not scroll anything if not needed)
        [self.collectionView scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionCenteredVertically animated:YES];
    }
    else {
        _previousAccessibilityHeadingSection = -1;
    }
}

@end
