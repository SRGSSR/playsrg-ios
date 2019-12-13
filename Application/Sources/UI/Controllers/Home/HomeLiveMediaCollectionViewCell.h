//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "Previewing.h"

#import <SRGDataProvider/SRGDataProvider.h>

NS_ASSUME_NONNULL_BEGIN

@interface HomeLiveMediaCollectionViewCell : UICollectionViewCell <Previewing>

- (void)setMedia:(nullable SRGMedia *)media featured:(BOOL)featured;

@end

NS_ASSUME_NONNULL_END
