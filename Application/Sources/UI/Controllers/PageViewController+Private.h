//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "PageViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface PageViewController (Private)

#pragma mark Display

- (BOOL)displayPageAtIndex:(NSInteger)index animated:(BOOL)animated;

- (void)updateTabForViewController:(UIViewController *)viewController animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
