//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "HomeShowListTableViewCell.h"

#import "HomeShowCollectionViewCell.h"
#import "Layout.h"
#import "ShowViewController.h"
#import "SwimlaneCollectionViewLayout.h"
#import "UIView+PlaySRG.h"

@import SRGAppearance;

// Small margin to avoid overlap with the horizontal scrolling indicator
static const CGFloat kBottomInset = 15.f;

@interface HomeShowListTableViewCell ()

@property (nonatomic, weak) UIView *wrapperView;
@property (nonatomic, weak) UICollectionView *collectionView;

@end

@implementation HomeShowListTableViewCell

#pragma mark Class overrides

+ (CGFloat)heightForHomeSectionInfo:(HomeSectionInfo *)homeSectionInfo bounds:(CGRect)bounds featured:(BOOL)featured
{
    return [self itemSizeForHomeSectionInfo:homeSectionInfo bounds:bounds featured:featured].height + kBottomInset;
}

#pragma mark Class methods

+ (CGSize)itemSizeForHomeSectionInfo:(HomeSectionInfo *)homeSectionInfo bounds:(CGRect)bounds featured:(BOOL)featured
{
    CGFloat itemWidth = 0.f;
    
    if (featured) {
        itemWidth = LayoutCollectionItemFeaturedWidth(CGRectGetWidth(bounds));
    }
    else {
        itemWidth = LayoutCollectionViewCellStandardWidth;
    }
    return LayoutShowStandardCollectionItemSize(itemWidth, featured);
}

#pragma mark Object lifecycle

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.backgroundColor = UIColor.clearColor;
        self.selectedBackgroundView.backgroundColor = UIColor.clearColor;
        
        UIView *wrapperView = [[UIView alloc] initWithFrame:self.contentView.bounds];
        wrapperView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.contentView addSubview:wrapperView];
        self.wrapperView = wrapperView;
        
        SwimlaneCollectionViewLayout *collectionViewLayout = [[SwimlaneCollectionViewLayout alloc] init];
        collectionViewLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        collectionViewLayout.minimumLineSpacing = LayoutStandardMargin;
        collectionViewLayout.minimumInteritemSpacing = LayoutStandardMargin;
        
        UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:wrapperView.bounds collectionViewLayout:collectionViewLayout];
        collectionView.backgroundColor = UIColor.clearColor;
        collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        collectionView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
        collectionView.alwaysBounceHorizontal = YES;
        collectionView.directionalLockEnabled = YES;
        collectionView.decelerationRate = UIScrollViewDecelerationRateFast;
        // Important. If > 1 view on-screen is found on iPhone with this property enabled, none will scroll to top
        collectionView.scrollsToTop = NO;
        collectionView.delegate = self;
        collectionView.dataSource = self;
        [wrapperView addSubview:collectionView];
        self.collectionView = collectionView;
        
        // Remark: The collection view is nested in a dummy view to workaround an accessibility bug
        //         See https://stackoverflow.com/a/38798448/760435
        wrapperView.accessibilityElements = @[collectionView];
        
        NSString *showCellIdentifier = NSStringFromClass(HomeShowCollectionViewCell.class);
        UINib *showCellNib = [UINib nibWithNibName:showCellIdentifier bundle:nil];
        [collectionView registerNib:showCellNib forCellWithReuseIdentifier:showCellIdentifier];
    }
    return self;
}

#pragma mark Overrides

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self.collectionView.collectionViewLayout invalidateLayout];
}

- (void)reloadData
{
    [super reloadData];
    
    [self.collectionView reloadData];
}

#pragma mark Getters and setters

- (void)setHomeSectionInfo:(HomeSectionInfo *)homeSectionInfo featured:(BOOL)featured
{
    [super setHomeSectionInfo:homeSectionInfo featured:featured];
    
    if (homeSectionInfo) {
        // Restore position in rows when scrolling vertically and returning to a previously scrolled row
        CGPoint contentOffset = [self.collectionView.collectionViewLayout targetContentOffsetForProposedContentOffset:homeSectionInfo.contentOffset];
        [self.collectionView setContentOffset:contentOffset animated:NO];
    }
    self.collectionView.scrollEnabled = (homeSectionInfo.items.count != 0);
}

#pragma mark UICollectionViewDataSource protocol

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return ! [self isEmpty] ? self.homeSectionInfo.items.count : 10 /* Display 10 placeholders */;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [collectionView dequeueReusableCellWithReuseIdentifier:NSStringFromClass(HomeShowCollectionViewCell.class) forIndexPath:indexPath];
}

#pragma mark UICollectionViewDelegate protocol

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(HomeShowCollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath
{
    SRGShow *show = ! [self isEmpty] ? self.homeSectionInfo.items[indexPath.row] : nil;
    [cell setShow:show featured:self.featured];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (! [self isEmpty]) {
        SRGShow *show = self.homeSectionInfo.items[indexPath.row];
        ShowViewController *showViewController = [[ShowViewController alloc] initWithShow:show fromPushNotification:NO];
        [self.play_nearestViewController.navigationController pushViewController:showViewController animated:YES];
    }
}

#pragma mark UICollectionViewDelegateFlowLayout protocol

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewFlowLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [HomeShowListTableViewCell itemSizeForHomeSectionInfo:self.homeSectionInfo bounds:collectionView.bounds featured:self.featured];
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewFlowLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    if (self.homeSectionInfo.homeSection == HomeSectionTVFavoriteShows || self.homeSectionInfo.homeSection == HomeSectionRadioFavoriteShows || self.homeSectionInfo.homeSection == HomeSectionRadioAllShows) {
        return UIEdgeInsetsMake(0.f, LayoutStandardMargin, kBottomInset, LayoutStandardMargin);
    }
    else {
        return UIEdgeInsetsMake(0.f, LayoutStandardMargin, 0.f, LayoutStandardMargin);
    }
}

#pragma mark UIScrollViewDelegate protocol

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    self.homeSectionInfo.contentOffset = scrollView.contentOffset;
}

@end
