//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "MediasViewController.h"

#import "LiveMediaCollectionViewCell.h"
#import "MediaCollectionViewCell.h"
#import "UIViewController+PlaySRG.h"

#import <SRGAppearance/SRGAppearance.h>

static const CGFloat kLayoutHorizontalInset = 10.f;

@implementation MediasViewController

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.emptyCollectionImage = [UIImage imageNamed:@"media-90"];
    
    NSString *cellIdentifier = NSStringFromClass(MediaCollectionViewCell.class);
    UINib *cellNib = [UINib nibWithNibName:cellIdentifier bundle:nil];
    [self.collectionView registerNib:cellNib forCellWithReuseIdentifier:cellIdentifier];
    
    NSString *liveCellIdentifier = NSStringFromClass(LiveMediaCollectionViewCell.class);
    UINib *liveCellNib = [UINib nibWithNibName:liveCellIdentifier bundle:nil];
    [self.collectionView registerNib:liveCellNib forCellWithReuseIdentifier:liveCellIdentifier];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(accessibilityVoiceOverStatusChanged:)
                                               name:UIAccessibilityVoiceOverStatusChanged
                                             object:nil];
}

#pragma mark UICollectionViewDataSource protocol

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.items.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [collectionView dequeueReusableCellWithReuseIdentifier:self.liveLargeCell ? NSStringFromClass(LiveMediaCollectionViewCell.class) : NSStringFromClass(MediaCollectionViewCell.class)
                                                     forIndexPath:indexPath];
}

#pragma mark UICollectionViewDelegate protocol

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.liveLargeCell) {
        LiveMediaCollectionViewCell *liveMediaCell = (LiveMediaCollectionViewCell *)cell;
        [liveMediaCell setMedia:self.items[indexPath.row]];
    }
    else {
        MediaCollectionViewCell *mediaCell = (MediaCollectionViewCell *)cell;
        [mediaCell setMedia:self.items[indexPath.row] withDateFormatter:self.dateFormatter];
    }
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    SRGMedia *media = self.items[indexPath.row];
    [self play_presentMediaPlayerWithMedia:media position:nil airPlaySuggestions:YES fromPushNotification:NO animated:YES completion:nil];
}

#pragma mark UICollectionViewDelegateFlowLayout protocol

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    return UIEdgeInsetsMake(10.f, kLayoutHorizontalInset, 10.f, kLayoutHorizontalInset);
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewFlowLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *contentSizeCategory = UIApplication.sharedApplication.preferredContentSizeCategory;
    
    // Large cell table layout
    if (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassCompact && self.liveLargeCell) {
        CGFloat width = CGRectGetWidth(collectionView.frame) - 2 * kLayoutHorizontalInset;
        CGFloat height = width * 9 / 16 + 100.f;
        return CGSizeMake(width, height);
    }
    // Line table layout
    else if (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassCompact) {
        CGFloat height = (SRGAppearanceCompareContentSizeCategories(contentSizeCategory, UIContentSizeCategoryExtraLarge) == NSOrderedAscending) ? 86.f : 100.f;
        return CGSizeMake(CGRectGetWidth(collectionView.frame) - 2 * kLayoutHorizontalInset, height);
    }
    // Grid layout
    else {
        CGFloat minTextHeight = (SRGAppearanceCompareContentSizeCategories(contentSizeCategory, UIContentSizeCategoryExtraLarge) == NSOrderedAscending) ? 90.f : 120.f;
        
        static const CGFloat kItemWidth = 210.f;
        return CGSizeMake(kItemWidth, ceilf(kItemWidth * 9.f / 16.f + minTextHeight));
    }
}

#pragma mark Notifications

- (void)accessibilityVoiceOverStatusChanged:(NSNotification *)notification
{
    [self.collectionView reloadData];
}

@end
