//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "CollectionRequestViewController.h"
#import "PlayApplicationNavigation.h"

#import <SRGAnalytics/SRGAnalytics.h>

NS_ASSUME_NONNULL_BEGIN

@interface SearchViewController : CollectionRequestViewController <PlayApplicationNavigation, SRGAnalyticsViewTracking, UISearchBarDelegate, UISearchControllerDelegate, UISearchResultsUpdating>

@end

NS_ASSUME_NONNULL_END
