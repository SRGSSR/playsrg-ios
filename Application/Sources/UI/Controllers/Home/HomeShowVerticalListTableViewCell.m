//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "HomeShowVerticalListTableViewCell.h"

#import "ShowCollectionViewCell.h"
#import "ShowViewController.h"

#import <SRGAppearance/SRGAppearance.h>

static const CGFloat kLayoutHorizontalInset = 10.f;

@interface HomeShowVerticalListTableViewCell ()

@property (nonatomic, weak) IBOutlet UIView *wrapperView;
@property (nonatomic, weak) IBOutlet UICollectionView *collectionView;

@end

@implementation HomeShowVerticalListTableViewCell

#pragma mark Class methods

+ (CGSize)itemSizeForHomeSectionInfo:(HomeSectionInfo *)homeSectionInfo bounds:(CGRect)bounds collectionViewLayout:(UICollectionViewFlowLayout *)collectionViewLayout
{
    // 2 items per row on small layouts, max cell width of 210
    CGFloat width = fminf(floorf((CGRectGetWidth(bounds) - collectionViewLayout.minimumInteritemSpacing - 2 * kLayoutHorizontalInset) / 2.f), 210.f);
    
    NSString *contentSizeCategory = UIApplication.sharedApplication.preferredContentSizeCategory;
    CGFloat minTextHeight = (SRGAppearanceCompareContentSizeCategories(contentSizeCategory, UIContentSizeCategoryExtraLarge) == NSOrderedAscending) ? 30.f : 50.f;
    
    return CGSizeMake(width, ceilf(width * 9.f / 16.f + minTextHeight));
}

#pragma mark Overrides

+ (CGFloat)heightForHomeSectionInfo:(HomeSectionInfo *)homeSectionInfo bounds:(CGRect)bounds featured:(BOOL)featured
{
    static UICollectionViewFlowLayout *s_collectionViewLayout;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        HomeShowVerticalListTableViewCell *headerView = [NSBundle.mainBundle loadNibNamed:NSStringFromClass(self) owner:nil options:nil].firstObject;
        s_collectionViewLayout = (UICollectionViewFlowLayout *)headerView.collectionView.collectionViewLayout;
    });
    
    CGSize itemSize = [self itemSizeForHomeSectionInfo:homeSectionInfo bounds:bounds collectionViewLayout:s_collectionViewLayout];
    NSInteger numberOfItemsPerRow = floorf((CGRectGetWidth(bounds) - 2 * kLayoutHorizontalInset + s_collectionViewLayout.minimumInteritemSpacing) / (itemSize.width + s_collectionViewLayout.minimumInteritemSpacing));
    NSInteger numberOfItems = (homeSectionInfo.items.count != 0) ? homeSectionInfo.items.count : 4;
    NSInteger numberOfLines = MAX(ceilf((float)numberOfItems / numberOfItemsPerRow), 1);
    return itemSize.height * numberOfLines + (numberOfLines - 1) * s_collectionViewLayout.minimumLineSpacing;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.backgroundColor = UIColor.clearColor;
    self.selectedBackgroundView.backgroundColor = UIColor.clearColor;
    
    self.collectionView.backgroundColor = UIColor.clearColor;
    self.collectionView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    self.collectionView.alwaysBounceHorizontal = NO;
    // Important. If > 1 view on-screen is found on iPhone with this property enabled, none will scroll to top
    self.collectionView.scrollsToTop = NO;
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    
    // Remark: The collection view is nested in a dummy view to workaround an accessibility bug
    //         See https://stackoverflow.com/a/38798448/760435
    self.wrapperView.accessibilityElements = @[self.collectionView];
    
    NSString *showCellIdentifier = NSStringFromClass(ShowCollectionViewCell.class);
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
    [super setHomeSectionInfo:homeSectionInfo featured:featured];
    
    [self.collectionView reloadData];
}

#pragma mark UICollectionViewDataSource protocol

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return ! [self isEmpty] ? self.homeSectionInfo.items.count : 4;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [collectionView dequeueReusableCellWithReuseIdentifier:NSStringFromClass(ShowCollectionViewCell.class) forIndexPath:indexPath];
}

#pragma mark UICollectionViewDelegate protocol

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(ShowCollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath
{
    SRGShow *show = ! [self isEmpty] ? self.homeSectionInfo.items[indexPath.row] : nil;
    [cell setShow:show featured:NO];
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

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    return UIEdgeInsetsMake(0.f, kLayoutHorizontalInset, 0.f, kLayoutHorizontalInset);
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewFlowLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [HomeShowVerticalListTableViewCell itemSizeForHomeSectionInfo:self.homeSectionInfo bounds:collectionView.bounds collectionViewLayout:collectionViewLayout];
}

@end
