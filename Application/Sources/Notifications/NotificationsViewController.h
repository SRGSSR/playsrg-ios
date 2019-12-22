//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "ContentInsets.h"
#import "DataViewController.h"
#import "NotificationTableViewCell.h"

#import <DZNEmptyDataSet/DZNEmptyDataSet.h>

NS_ASSUME_NONNULL_BEGIN

@interface NotificationsViewController : DataViewController <ContentInsets, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate, NotificationTableViewCellDelegate, UITableViewDataSource, UITableViewDelegate>

+ (void)openNotification:(Notification *)notification fromViewController:(UIViewController *)viewController;

@end

NS_ASSUME_NONNULL_END
