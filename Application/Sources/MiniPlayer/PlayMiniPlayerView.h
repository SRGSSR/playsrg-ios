//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <SRGDataProvider/SRGDataProvider.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PlayMiniPlayerView : UIView

@property (class, nonatomic, readonly) PlayMiniPlayerView *view;

@property (nonatomic, readonly) SRGMedia *media;

@end

NS_ASSUME_NONNULL_END
