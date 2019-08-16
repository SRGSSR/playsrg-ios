//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "MediasViewController.h"

#import "MediaCollectionViewCell.h"
#import "UIViewController+PlaySRG.h"

#import <libextobjc/libextobjc.h>
#import <SRGAppearance/SRGAppearance.h>

static const CGFloat kLayoutHorizontalInset = 10.f;

@interface MediasViewController ()

@property (nonatomic, getter=isDisplayingMediaType) BOOL displayingMediaType;

@end

@implementation MediasViewController

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.emptyCollectionImage = [UIImage imageNamed:@"media-90"];
    
    NSString *cellIdentifier = NSStringFromClass(MediaCollectionViewCell.class);
    UINib *cellNib = [UINib nibWithNibName:cellIdentifier bundle:nil];
    [self.collectionView registerNib:cellNib forCellWithReuseIdentifier:cellIdentifier];
}

#pragma mark UICollectionViewDataSource protocol

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.items.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [collectionView dequeueReusableCellWithReuseIdentifier:NSStringFromClass(MediaCollectionViewCell.class)
                                                     forIndexPath:indexPath];
}

#pragma mark UICollectionViewDelegate protocol

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(MediaCollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath
{
    [cell setMedia:self.items[indexPath.row] withDateFormatter:self.dateFormatter displayingMediaType:self.displayingMediaType];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    SRGMedia *media = self.items[indexPath.row];
    [self play_presentMediaPlayerWithMedia:media position:nil fromPushNotification:NO animated:YES completion:nil];
}

#pragma mark UICollectionViewDelegateFlowLayout protocol

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    return UIEdgeInsetsMake(10.f, kLayoutHorizontalInset, 10.f, kLayoutHorizontalInset);
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewFlowLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *contentSizeCategory = UIApplication.sharedApplication.preferredContentSizeCategory;
    
    // Table layout
    if (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassCompact) {
        CGFloat height = (SRGAppearanceCompareContentSizeCategories(contentSizeCategory, UIContentSizeCategoryExtraLarge) == NSOrderedAscending) ? 86.f : 100.f;
        return CGSizeMake(CGRectGetWidth(collectionView.frame) - 2 * kLayoutHorizontalInset, height);
    }
    // Grid layout
    else {
        CGFloat minTextHeight = (SRGAppearanceCompareContentSizeCategories(contentSizeCategory, UIContentSizeCategoryExtraLarge) == NSOrderedAscending) ? 70.f : 100.f;
        
        static const CGFloat kItemWidth = 210.f;
        return CGSizeMake(kItemWidth, ceilf(kItemWidth * 9.f / 16.f + minTextHeight));
    }
}

#pragma mark Overrides

- (void)refreshDidFinishWithError:(nullable NSError *)error
{
    [super refreshDidFinishWithError:error];
    
    NSString *keyPath = [NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGMedia.new, mediaType)];
    NSArray<NSNumber *>* mediaTypes = [self.items valueForKeyPath:keyPath];
    self.displayingMediaType = (mediaTypes.count > 1);
}

@end
