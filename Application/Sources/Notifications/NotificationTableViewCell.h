//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "Notification.h"

#import <MGSwipeTableCell/MGSwipeTableCell.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NotificationTableViewCell : MGSwipeTableCell

@property (nonatomic, nullable) Notification *notification;

@end

NS_ASSUME_NONNULL_END
