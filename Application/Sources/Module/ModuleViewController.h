//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "MediasViewController.h"

@import SRGAnalytics;
@import SRGDataProvider;

NS_ASSUME_NONNULL_BEGIN

@interface ModuleViewController : MediasViewController <SRGAnalyticsViewTracking, UIGestureRecognizerDelegate>

- (instancetype)initWithModule:(SRGModule *)module;

@end

@interface ModuleViewController (Unavailable)

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
