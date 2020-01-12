//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "HomeSectionInfo.h"
#import "PageViewController.h"
#import "PlayApplicationNavigation.h"

#import <SRGAnalytics/SRGAnalytics.h>

NS_ASSUME_NONNULL_BEGIN

@interface LivesViewController : PageViewController <PlayApplicationNavigation, SRGAnalyticsViewTracking>

- (instancetype)initWithHomeSections:(NSArray<NSNumber *> *)homeSections;

@end

@interface LivesViewController (Unavailable)

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
