//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "TabStrip.h"

#import "PageViewController+Private.h"
#import "PlayLogger.h"
#import "TabStripCell.h"

#import <libextobjc/libextobjc.h>
#import <MAKVONotificationCenter/MAKVONotificationCenter.h>
#import <Masonry/Masonry.h>

// The animation duration must not be shorter than the page view controller animation to avoid glitches
static const NSTimeInterval TabStripIndicatorAnimationDuration = 0.4;

// Function declarations
static void commonInit(TabStrip *self);

@interface TabStrip ()

@property (nonatomic) NSArray<PageItem *> *items;

@property (nonatomic, weak) UICollectionView *collectionView;
@property (nonatomic, weak) UIView *indicatorView;

@property (nonatomic, getter=isAnimating) BOOL animating;

@property (nonatomic, weak) PageViewController *pageViewController;

@end

@implementation TabStrip

#pragma mark Object lifecycle

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        commonInit(self);
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        commonInit(self);
    }
    return self;
}

#pragma mark Getters and setters

- (void)setPageViewController:(PageViewController *)pageViewController withInitialSelectedIndex:(NSInteger)initialSelectedIndex
{
    NSAssert(pageViewController.viewControllers.count != 0, @"At least one view controller is required");
    
    UIPageViewController *internalPageViewController = pageViewController.pageViewController;
    NSAssert(internalPageViewController.delegate == nil, @"The current implementation is not generic and only works if no delegate has been set");
    NSAssert(internalPageViewController.transitionStyle == UIPageViewControllerTransitionStyleScroll, @"Only compatible with scrollable page view controllers");
    
    for (UIViewController *viewController in self.pageViewController.pageViewController.viewControllers) {
        [viewController removeObserver:self keyPath:@keypath(viewController.play_pageItem)];
    }
    
    internalPageViewController.delegate = self;
    
    for (UIViewController *viewController in pageViewController.viewControllers) {
        @weakify(pageViewController)
        [viewController addObserver:self keyPath:@keypath(viewController.play_pageItem) options:0 block:^(MAKVONotification *notification) {
            @strongify(pageViewController)
            
            if (! pageViewController) {
                return;
            }
            
            self.items = [self pageItemsForViewControllers:pageViewController.viewControllers];
            [self reloadData];
            
            // Center on the selected index again
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.selectedIndex inSection:0];
            [self.collectionView scrollToItemAtIndexPath:indexPath
                                        atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                                animated:NO];
        }];
    }
    
    self.items = [self pageItemsForViewControllers:pageViewController.viewControllers];
    self.selectedIndex = initialSelectedIndex;
    self.pageViewController = pageViewController;
    
    // Synchronize with page view controller scrolling
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(UIView * _Nullable view, NSDictionary<NSString *,id> * _Nullable bindings) {
        return [view isKindOfClass:UIScrollView.class];
    }];
    UIScrollView *scrollView = [internalPageViewController.view.subviews filteredArrayUsingPredicate:predicate].firstObject;
    if (! scrollView) {
        return;
    }
    
    // A page view controller has has a content size of 3 times its width (1 contribution for the current content,
    // 1 for the left page, 1 for the right page). Depending on the scroll direction (determined by the current
    // offset monitored via KVO), we can move the indicator according to where the user is headed.
    
    @weakify(scrollView)
    [scrollView addObserver:self keyPath:@keypath(scrollView.contentOffset) options:0 block:^(MAKVONotification *notification) {
        @strongify(scrollView)
        
        // If animating (might be between non-neighbouring indices), do not synchronize
        if (self.animating) {
            return;
        }
        
        NSInteger targetIndex = 0;
        UICollectionViewScrollPosition scrollPosition = UICollectionViewScrollPositionNone;
        
        CGFloat scrollWidth = CGRectGetWidth(scrollView.frame);
        if (scrollView.contentOffset.x >= scrollWidth && self.selectedIndex < self.items.count - 1) {
            targetIndex = self.selectedIndex + 1;
            scrollPosition = UICollectionViewScrollPositionRight;
        }
        else if (scrollView.contentOffset.x < scrollWidth && self.selectedIndex > 0) {
            targetIndex = self.selectedIndex - 1;
            scrollPosition = UICollectionViewScrollPositionLeft;
        }
        else {
            return;
        }
        
        CGRect currentIndicatorViewFrame = [self indicatorViewFrameForIndex:self.selectedIndex];
        CGRect targetIndicatorViewFrame = [self indicatorViewFrameForIndex:targetIndex];
        
        CGFloat progress = fabs(scrollView.contentOffset.x - scrollWidth) / scrollWidth;
        CGFloat minX = (1.f - progress) * CGRectGetMinX(currentIndicatorViewFrame) + progress * CGRectGetMinX(targetIndicatorViewFrame);
        CGFloat width = (1.f - progress) * CGRectGetWidth(currentIndicatorViewFrame) + progress * CGRectGetWidth(targetIndicatorViewFrame);
        
        self.indicatorView.frame = CGRectMake(minX,
                                              CGRectGetMinY(currentIndicatorViewFrame),
                                              width,
                                              CGRectGetHeight(currentIndicatorViewFrame));
        
        // If the target cell is not visible, scroll to make it visible ASAP (in the correct scroll position depending on whether
        // the pages are browsed forward or backward). Override the default animation duration for a perfect result.
        if (! CGRectContainsRect(self.bounds, targetIndicatorViewFrame)) {
            [UIView animateWithDuration:0.2 delay:0. options:UIViewAnimationOptionAllowUserInteraction animations:^{
                NSIndexPath *targetIndexPath = [NSIndexPath indexPathForRow:targetIndex inSection:0];
                [self.collectionView scrollToItemAtIndexPath:targetIndexPath
                                            atScrollPosition:scrollPosition
                                                    animated:NO];
            } completion:nil];
        }
    }];
}

- (void)setSelectedIndex:(NSInteger)selectedIndex
{
    _selectedIndex = selectedIndex;
    
    [self updateTabAppearance];
}

#pragma mark Overrides

- (void)willMoveToWindow:(UIWindow *)newWindow
{
    [super willMoveToWindow:newWindow];
    
    if (newWindow) {
        [self reloadData];
        [self updateTabAppearance];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self.collectionView.collectionViewLayout invalidateLayout];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateIndicatorViewFrame];
        
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.selectedIndex inSection:0];
        [self.collectionView scrollToItemAtIndexPath:indexPath
                                    atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                            animated:NO];
    });
}

#pragma mark UI

- (void)updateTabAppearance
{
    for (UIView *subview in self.collectionView.subviews) {
        if (! [subview isKindOfClass:TabStripCell.class]) {
            continue;
        }
        
        TabStripCell *cell = (TabStripCell *)subview;
        NSInteger index = [self.items indexOfObject:cell.item];
        cell.current = (index == self.selectedIndex);
    }
}

- (void)updateIndicatorViewFrame
{
    self.indicatorView.frame = [self indicatorViewFrameForIndex:self.selectedIndex];
}

- (NSArray<PageItem *> *)pageItemsForViewControllers:(NSArray<UIViewController *> *)viewControllers
{
    NSMutableArray<PageItem *> *items = [NSMutableArray array];
    for (UIViewController *viewController in viewControllers) {
        if (viewController.play_pageItem) {
            [items addObject:viewController.play_pageItem];
        }
        else {
            PageItem *item = [[PageItem alloc] initWithTitle:@"Untitled" image:nil];
            [items addObject:item];
        }
    }
    return items.copy;
}

- (CGRect)indicatorViewFrameForIndex:(NSInteger)index
{
    if (index < 0 || index >= self.items.count) {
        return CGRectZero;
    }
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
    UICollectionViewLayoutAttributes *layoutAttributes = [self.collectionView layoutAttributesForItemAtIndexPath:indexPath];
    if (! layoutAttributes) {
        return CGRectZero;
    }
    
    CGRect frameInSelf = [self convertRect:layoutAttributes.frame fromView:self.collectionView];
    
    static const CGFloat kIndicatorViewHeight = 2.f;
    return CGRectMake(CGRectGetMinX(frameInSelf),
                      CGRectGetMaxY(frameInSelf) - kIndicatorViewHeight,
                      CGRectGetWidth(frameInSelf),
                      kIndicatorViewHeight);
}

- (void)reloadData
{
    [self.collectionView reloadData];
    
    // Perform after collection view reload
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateIndicatorViewFrame];
        [self updateTabAppearance];
    });
}

#pragma mark UICollectionViewDataSource protocol

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.items.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [collectionView dequeueReusableCellWithReuseIdentifier:NSStringFromClass(TabStripCell.class) forIndexPath:indexPath];
}

#pragma mark UICollectionViewDelegate protocol

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(TabStripCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath
{
    cell.item = self.items[indexPath.row];
    [self updateTabAppearance];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSUInteger newIndex = indexPath.row;
    
    if (self.selectedIndex == newIndex) {
        return;
    }
    
    self.selectedIndex = newIndex;
    
    // Immediately start scrolling for faster snapping to the final location
    [self.collectionView scrollToItemAtIndexPath:indexPath
                                atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                        animated:YES];
    
    // We cannot animate the page view controller and the tab strip indicator within the same animation transaction
    // (`UIPageViewController` animations cannot be wrapped into an animation block). Moreover, the tab strip page
    // view scrolling sync is only meant for neighbouring pages, while selection allows to jump at arbitrary pages.
    // Therefore:
    //   1) We set an 'animating' flag during the animation to prevent scroll sync.
    //   2) We animate the indicator separately. The completion block of the page view controller animation is unreliable
    //      (page scrolling still occurs after it has been called, and sometimes the block does not event get called!).
    //      Therefore we only associate the `animating` flag with the indicator animation, which must have a duration
    //      longer than the page view controller animation.
    
    self.animating = YES;
    
    // Remove animations for a better result if the user selects a new index before the previous selection animation
    // is not complete yet
    [self.indicatorView.layer removeAllAnimations];
    [UIView animateWithDuration:TabStripIndicatorAnimationDuration animations:^{
        self.indicatorView.frame = [self indicatorViewFrameForIndex:newIndex];
    } completion:^(BOOL finished) {
        if (finished) {
            self.animating = NO;
        }
    }];
    
    // Animate the page
    [self.pageViewController switchToIndex:newIndex animated:YES];
}

#pragma mark UICollectionViewDelegateFlowLayout protocol

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat height = CGRectGetHeight(collectionView.frame);
    return CGSizeMake([TabStripCell widthForItem:self.items[indexPath.row] withHeight:height], height);
}

#pragma mark UIPageViewControllerDelegate protocol

- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers transitionCompleted:(BOOL)completed
{
    // Since we are loading pages on the fly, the view controller arrays contain only one element (the page currently displayed)
    UIViewController *selectedViewController = completed ? pageViewController.viewControllers.firstObject : previousViewControllers.firstObject;
    self.selectedIndex = [self.pageViewController.viewControllers indexOfObject:selectedViewController];
    
    [self.indicatorView.layer removeAllAnimations];
    [UIView animateWithDuration:TabStripIndicatorAnimationDuration animations:^{
        self.indicatorView.frame = [self indicatorViewFrameForIndex:self.selectedIndex];
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.selectedIndex inSection:0];
        [self.collectionView scrollToItemAtIndexPath:indexPath
                                    atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally
                                            animated:NO];
    } completion:nil];
}

#pragma mark UIScrollViewDelegate protocol

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self updateIndicatorViewFrame];
}

#pragma mark Notifications

- (void)contentSizeCategoryDidChange:(NSNotification *)notification
{
    [self reloadData];
}

#pragma mark Interface Builder integration

- (void)prepareForInterfaceBuilder
{
    [super prepareForInterfaceBuilder];
    
    NSMutableArray<PageItem *> *items = [NSMutableArray array];
    
    PageItem *item1 = [[PageItem alloc] initWithTitle:@"Page 1" image:nil];
    [items addObject:item1];
    
    PageItem *item2 = [[PageItem alloc] initWithTitle:@"Page 2" image:nil];
    [items addObject:item2];
    
    PageItem *item3 = [[PageItem alloc] initWithTitle:@"Page 3" image:nil];
    [items addObject:item3];
    
    self.items = items.copy;
    [self.collectionView reloadData];
}

@end

static void commonInit(TabStrip *self)
{
    // Add dummy view as first subview to avoid the collection view adjusting with respect to layout guides
    UIView *dummyView = [[UIView alloc] initWithFrame:CGRectZero];
    dummyView.backgroundColor = UIColor.clearColor;
    [self addSubview:dummyView];
    
    UICollectionViewFlowLayout *collectionViewLayout = [[UICollectionViewFlowLayout alloc] init];
    collectionViewLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    collectionViewLayout.minimumInteritemSpacing = 0.f;
    
    // There is a layout bug with spacing != 0, which makes cells appear and disappear incorrectly at collection view ends
    // when calling `-scrollToItem` for a non-visible item. The same issue in fact affects custom layouts as well, which
    // probably means there is a bug in how layout attributes are interpreted in such cases.
    // TODO: Write a bug report with a simple example of a custom layout
    collectionViewLayout.minimumLineSpacing = 0.f;
    collectionViewLayout.sectionInset = UIEdgeInsetsMake(0.f, 30.f, 0.f, 0.f);
    
    UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:collectionViewLayout];
    collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    collectionView.showsHorizontalScrollIndicator = NO;
    [self addSubview:collectionView];
    self.collectionView = collectionView;
    
    collectionView.dataSource = self;
    collectionView.delegate = self;
    
    collectionView.backgroundColor = UIColor.clearColor;
    collectionView.alwaysBounceHorizontal = YES;
    
    NSString *identifier = NSStringFromClass(TabStripCell.class);
    UINib *nib = [UINib nibWithNibName:identifier bundle:[NSBundle bundleForClass:self.class]];
    [collectionView registerNib:nib forCellWithReuseIdentifier:identifier];
    
    [collectionView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self);
    }];
    
    UIView *indicatorView = [[UIView alloc] initWithFrame:CGRectZero];
    indicatorView.backgroundColor = UIColor.whiteColor;
    indicatorView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:indicatorView];
    self.indicatorView = indicatorView;
    
    // Respond to font size setting changes
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(contentSizeCategoryDidChange:)
                                               name:UIContentSizeCategoryDidChangeNotification
                                             object:nil];
}
