//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "ContentInsets.h"
#import "PlayApplicationNavigation.h"
#import "RequestViewController.h"
#import "RadioChannel.h"

#import <DZNEmptyDataSet/UIScrollView+EmptyDataSet.h>

NS_ASSUME_NONNULL_BEGIN

@interface HomeViewController : RequestViewController <ContentInsets, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate, PlayApplicationNavigation, UITableViewDataSource, UITableViewDelegate>

/**
 *  Instantiate for the home page belonging to the specified radio channel. If no channel is provided, the TV home page will be
 *  displayed instead.
 */
- (instancetype)initWithRadioChannel:(nullable RadioChannel *)radioChannel NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly, nullable) RadioChannel *radioChannel;

@end

@interface HomeViewController (Unavailable)

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

