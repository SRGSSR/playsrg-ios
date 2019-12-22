//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIDevice (PlaySRG)

/**
 *  Return YES when the device is locked.
 */
@property (class, nonatomic, readonly) BOOL play_isLocked;

/**
 *  Return YES when the device is in landscape.
 */
@property (class, nonatomic, readonly) BOOL play_isLandscape;

@end

NS_ASSUME_NONNULL_END
