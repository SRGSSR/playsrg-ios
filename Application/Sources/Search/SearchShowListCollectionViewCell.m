//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SearchShowListCollectionViewCell.h"

#import "AnalyticsConstants.h"
#import "Layout.h"
#import "PlaySRG-Swift.h"
#import "SwimlaneCollectionViewLayout.h"
#import "UIView+PlaySRG.h"

@import SRGAnalytics;
@import SRGAppearance;

@interface SearchShowListCollectionViewCell ()

@property (nonatomic, weak) IBOutlet UICollectionView *collectionView;

@end

@implementation SearchShowListCollectionViewCell

#pragma mark Object lifecycle

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = UIColor.clearColor;
        
        SwimlaneCollectionViewLayout *collectionViewLayout = [[SwimlaneCollectionViewLayout alloc] init];
        collectionViewLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        
        UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:self.contentView.bounds collectionViewLayout:collectionViewLayout];
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
        [self.contentView addSubview:collectionView];
        self.collectionView = collectionView;
    }
    return self;
}

#pragma mark Getters and setters

- (void)setShows:(NSArray *)shows
{
    NSArray<SRGShow *> *previousShows = _shows;
    _shows = shows;
    
    [self.collectionView reloadData];
    
    // When a cell is reused to display a different show list, return to offset zero
    if (! [previousShows isEqualToArray:shows]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.collectionView setContentOffset:CGPointZero animated:NO];
        });
    }
}

#pragma mark Overrides

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    self.shows = nil;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self.collectionView.collectionViewLayout invalidateLayout];
}

#pragma mark UICollectionViewDataSource protocol

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.shows.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [collectionView showCellFor:indexPath show:self.shows[indexPath.row]];
}

#pragma mark UICollectionViewDelegate protocol

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    SRGShow *show = self.shows[indexPath.row];
    SectionViewController *showViewController = [SectionViewController showViewControllerFor:show];
    [self.play_nearestViewController.navigationController pushViewController:showViewController animated:YES];
    
    SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
    labels.value = show.URN;
    labels.type = AnalyticsTypeActionDisplayShow;
    [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleSearchOpen labels:labels];
    
    [[SRGDataProvider.currentDataProvider increaseSearchResultsViewCountForShow:show withCompletionBlock:^(SRGShowStatisticsOverview * _Nullable showStatisticsOverview, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        // Nothing
    }] resume];
}

- (UIContextMenuConfiguration *)collectionView:(UICollectionView *)collectionView contextMenuConfigurationForItemAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point
{
    return [ContextMenuObjC configurationFor:self.shows[indexPath.row] at:indexPath in:self.play_nearestViewController];
}

- (UITargetedPreview *)collectionView:(UICollectionView *)collectionView previewForHighlightingContextMenuWithConfiguration:(UIContextMenuConfiguration *)configuration
{
    return [self previewForConfiguration:configuration inCollectionView:collectionView];
}

- (UITargetedPreview *)collectionView:(UICollectionView *)collectionView previewForDismissingContextMenuWithConfiguration:(UIContextMenuConfiguration *)configuration
{
    return [self previewForConfiguration:configuration inCollectionView:collectionView];
}

- (UITargetedPreview *)previewForConfiguration:(UIContextMenuConfiguration *)configuration inCollectionView:(UICollectionView *)collectionView
{
    UIView *interactionView = [ContextMenuObjC interactionViewInCollectionView:collectionView with:configuration];
    if (! interactionView) {
        return nil;
    }
    
    UIPreviewParameters *parameters = [[UIPreviewParameters alloc] init];
    parameters.backgroundColor = UIColor.srg_gray16Color;
    return [[UITargetedPreview alloc] initWithView:interactionView parameters:parameters];
}

#pragma mark UICollectionViewDelegateFlowLayout protocol

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewFlowLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [[ShowCellSize swimlane] constrainedBy:collectionView];
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewFlowLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    return UIEdgeInsetsMake(0.f, 2 * LayoutMargin, 15.f, 2 * LayoutMargin);
}

@end
