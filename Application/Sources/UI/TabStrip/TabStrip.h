//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "PageViewController.h"

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  A Youtube-like tab strip control used by a `PageViewController`. It displays tabs in a scrollable area, with 
 *  the currently selected tab identified by a line indicator. Each tab can display a title or an image, defined
 *  by having view controllers specify an associated `PageItem`.
 */
IB_DESIGNABLE
@interface TabStrip : UIView <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIPageViewControllerDelegate>

- (void)setPageViewController:(PageViewController *)pageViewController withInitialSelectedIndex:(NSInteger)initialSelectedIndex;

@property (nonatomic) NSInteger selectedIndex;

@end

NS_ASSUME_NONNULL_END
