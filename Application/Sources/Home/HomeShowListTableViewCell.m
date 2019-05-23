//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "HomeShowListTableViewCell.h"

#import "HomeShowCollectionViewCell.h"
#import "Play-Swift-Bridge.h"
#import "ShowViewController.h"

#import <CoconutKit/CoconutKit.h>
#import <SRGAppearance/SRGAppearance.h>

static const CGFloat HomeStandardMargin = 10.f;

@interface HomeShowListTableViewCell ()

@property (nonatomic, weak) IBOutlet UIView *wrapperView;
@property (nonatomic, weak) IBOutlet UICollectionView *collectionView;

@end

@implementation HomeShowListTableViewCell

#pragma mark Overrides

+ (CGFloat)heightForHomeSectionInfo:(HomeSectionInfo *)homeSectionInfo bounds:(CGRect)bounds featured:(BOOL)featured
{
    return [self itemSizeForHomeSectionInfo:homeSectionInfo bounds:bounds featured:featured].height;
}

+ (CGSize)itemSizeForHomeSectionInfo:(HomeSectionInfo *)homeSectionInfo bounds:(CGRect)bounds featured:(BOOL)featured
{
    CGFloat itemWidth = 0.f;
    
    if (featured) {
        // Ensure cells never fill the entire width of the parent, so that the fact that content can be scrolled
        // is always obvious to the user
        static const CGFloat kHorizontalFillRatio = 0.9f;
        
        // Do not make cells unnecessarily large, especially on iPhone Plus
        UITraitCollection *traitCollection = UIApplication.sharedApplication.keyWindow.traitCollection;
        CGFloat maxWidth = (traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact) ? 300.f : 650.f;
        
        itemWidth = MIN(CGRectGetWidth(bounds) * kHorizontalFillRatio, maxWidth);
    }
    else {
        itemWidth = 210.f;
    }
    
    // Adjust height depending on font size settings. First section cells are different and require specific values
    static NSDictionary<NSString *, NSNumber *> *s_featuredTextHeigths;
    static NSDictionary<NSString *, NSNumber *> *s_standardTextHeigths;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        s_featuredTextHeigths = @{ UIContentSizeCategoryExtraSmall : @40,
                                   UIContentSizeCategorySmall : @40,
                                   UIContentSizeCategoryMedium : @43,
                                   UIContentSizeCategoryLarge : @45,
                                   UIContentSizeCategoryExtraLarge : @48,
                                   UIContentSizeCategoryExtraExtraLarge : @50,
                                   UIContentSizeCategoryExtraExtraExtraLarge : @55,
                                   UIContentSizeCategoryAccessibilityMedium : @55,
                                   UIContentSizeCategoryAccessibilityLarge : @55,
                                   UIContentSizeCategoryAccessibilityExtraLarge : @55,
                                   UIContentSizeCategoryAccessibilityExtraExtraLarge : @55,
                                   UIContentSizeCategoryAccessibilityExtraExtraExtraLarge : @55 };
        
        s_standardTextHeigths = @{ UIContentSizeCategoryExtraSmall : @35,
                                   UIContentSizeCategorySmall : @35,
                                   UIContentSizeCategoryMedium : @35,
                                   UIContentSizeCategoryLarge : @38,
                                   UIContentSizeCategoryExtraLarge : @40,
                                   UIContentSizeCategoryExtraExtraLarge : @43,
                                   UIContentSizeCategoryExtraExtraExtraLarge : @49,
                                   UIContentSizeCategoryAccessibilityMedium : @49,
                                   UIContentSizeCategoryAccessibilityLarge : @49,
                                   UIContentSizeCategoryAccessibilityExtraLarge : @49,
                                   UIContentSizeCategoryAccessibilityExtraExtraLarge : @49,
                                   UIContentSizeCategoryAccessibilityExtraExtraExtraLarge : @49 };
    });
    
    NSString *contentSizeCategory = UIApplication.sharedApplication.preferredContentSizeCategory;
    CGFloat minTextHeight = featured ? s_featuredTextHeigths[contentSizeCategory].floatValue : s_standardTextHeigths[contentSizeCategory].floatValue;
    
    return CGSizeMake(itemWidth, ceilf(itemWidth * 9.f / 16.f + minTextHeight));
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.backgroundColor = UIColor.clearColor;
    self.selectedBackgroundView.backgroundColor = UIColor.clearColor;
    
    self.collectionView.backgroundColor = UIColor.clearColor;
    self.collectionView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    self.collectionView.alwaysBounceHorizontal = YES;
    self.collectionView.directionalLockEnabled = YES;
    // Important. If > 1 view on-screen is found on iPhone with this property enabled, none will scroll to top
    self.collectionView.scrollsToTop = NO;
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    
    // Remark: The collection view is nested in a dummy view to workaround an accessibility bug
    //         See https://stackoverflow.com/a/38798448/760435
    self.wrapperView.accessibilityElements = @[self.collectionView];
    
    NSString *showCellIdentifier = NSStringFromClass(HomeShowCollectionViewCell.class);
    UINib *showCellNib = [UINib nibWithNibName:showCellIdentifier bundle:nil];
    [self.collectionView registerNib:showCellNib forCellWithReuseIdentifier:showCellIdentifier];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self.collectionView.collectionViewLayout invalidateLayout];
}

#pragma mark Getters and setters

- (void)setHomeSectionInfo:(HomeSectionInfo *)homeSectionInfo featured:(BOOL)featured
{
    [self.collectionView reloadDataAnimatedWithOldObjects:self.homeSectionInfo.items newObjects:homeSectionInfo.items section:0 updateData:^{
        [super setHomeSectionInfo:homeSectionInfo featured:featured];
    } completion:nil];
}

#pragma mark UICollectionViewDataSource protocol

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if (! [self isEmpty]) {
        return self.homeSectionInfo.items.count;
    }
    else {
        static const NSInteger kDefaultNumberOfPlaceholders = 10;
        
        NSInteger numberOfItems = 0;
        
        switch (self.homeSectionInfo.homeSection) {
            case HomeSectionTVLive: {
                numberOfItems = ApplicationConfiguration.sharedApplicationConfiguration.tvNumberOfLivePlaceholders;
                break;
            }
                
            case HomeSectionRadioLive: {
                NSString *identifier = self.homeSectionInfo.identifier;
                if (identifier) {
                    numberOfItems = [ApplicationConfiguration.sharedApplicationConfiguration radioChannelForUid:identifier].numberOfLivePlaceholders;
                }
                break;
            }
                
            default: {
                numberOfItems = kDefaultNumberOfPlaceholders; /* sufficient number of placeholders to accommodate all layouts */
                break;
            }
        }
        
        return (numberOfItems != 0) ? numberOfItems : kDefaultNumberOfPlaceholders;
    }
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [collectionView dequeueReusableCellWithReuseIdentifier:NSStringFromClass(HomeShowCollectionViewCell.class) forIndexPath:indexPath];
}

#pragma mark UICollectionViewDelegate protocol

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath
{
    SRGShow *show = ! [self isEmpty] ? self.homeSectionInfo.items[indexPath.row] : nil;
    
    HomeShowCollectionViewCell *showCell = (HomeShowCollectionViewCell *)cell;
    [showCell setShow:show featured:self.featured];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (! [self isEmpty]) {
        SRGShow *show = self.homeSectionInfo.items[indexPath.row];
        ShowViewController *showViewController = [[ShowViewController alloc] initWithShow:show fromPushNotification:NO];
        [self.nearestViewController.navigationController pushViewController:showViewController animated:YES];
    }
}

#pragma mark UICollectionViewDelegateFlowLayout protocol

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewFlowLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    // For compact layouts, display a single item with the full available collection width (up to a small margin)
    if (self.featured
            && [self collectionView:collectionView numberOfItemsInSection:indexPath.section] == 1
            && self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassCompact) {
        return CGSizeMake(CGRectGetWidth(collectionView.frame) - 2 * HomeStandardMargin, CGRectGetHeight(collectionView.frame));
    }
    else {
        return [HomeShowListTableViewCell itemSizeForHomeSectionInfo:self.homeSectionInfo bounds:collectionView.bounds featured:self.featured];
    }
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewFlowLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    // If a single item has been displayed, center it
    if (self.featured && [self collectionView:collectionView numberOfItemsInSection:section] == 1) {
        CGSize cellSize = [self collectionView:collectionView layout:collectionViewLayout sizeForItemAtIndexPath:[NSIndexPath indexPathWithIndex:section]];
        CGFloat margin = (CGRectGetWidth(collectionView.frame) - cellSize.width) / 2.f;
        return UIEdgeInsetsMake(0.f, margin, 0.f, margin);
    }
    else if (self.homeSectionInfo.module) {
        return UIEdgeInsetsMake(0.f, collectionViewLayout.minimumInteritemSpacing, 0.f, HomeStandardMargin);
    }
    else {
        return UIEdgeInsetsMake(0.f, HomeStandardMargin, 0.f, HomeStandardMargin);
    }
}

#pragma mark UIScrollViewDelegate protocol

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    // Delay content offset recording so that we don't record a content offset before restoring a content offset
    // (which also is made with a slight delay)
    dispatch_async(dispatch_get_main_queue(), ^{
        self.homeSectionInfo.contentOffset = scrollView.contentOffset;
    });
}

@end
