//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "BaseViewController.h"

#import <CoconutKit/CoconutKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LibraryViewController : BaseViewController <UITableViewDataSource, UITableViewDelegate>

- (void)scrollToTopAnimated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
