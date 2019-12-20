//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "CollectionRequestViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface MediasViewController : CollectionRequestViewController

// An optional date formatter to use when displaying media information (if `nil`, a standard formatting will be applied).
@property (nonatomic, nullable) NSDateFormatter *dateFormatter;

@property (nonatomic, getter=isLiveLargeCell) BOOL liveLargeCell;

@end

NS_ASSUME_NONNULL_END
