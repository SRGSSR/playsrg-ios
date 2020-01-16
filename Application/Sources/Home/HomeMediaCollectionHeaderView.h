//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "HomeSectionInfo.h"
#import "Previewing.h"

#import <SRGDataProvider/SRGDataProvider.h>

NS_ASSUME_NONNULL_BEGIN

@interface HomeMediaCollectionHeaderView : UICollectionReusableView <Previewing>

@property (nonatomic) CGFloat leftEdgeInset;

/*
 *  Set the HomeSectionInfo. The module or topic property is used to populate the view
 */
- (void)setHomeSectionInfo:(nullable HomeSectionInfo *)homeSectionInfo featured:(BOOL)featured;

@end

NS_ASSUME_NONNULL_END
