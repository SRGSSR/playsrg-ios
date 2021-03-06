//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "HomeSectionInfo.h"

@import SRGDataProvider;
@import UIKit;

NS_ASSUME_NONNULL_BEGIN

@interface HomeTableViewCell : UITableViewCell

+ (CGFloat)heightForHomeSectionInfo:(HomeSectionInfo *)homeSectionInfo bounds:(CGRect)bounds featured:(BOOL)featured;

@property (nonatomic, readonly, nullable) HomeSectionInfo *homeSectionInfo;
@property (nonatomic, readonly, getter=isFeatured) BOOL featured;

- (void)setHomeSectionInfo:(nullable HomeSectionInfo *)homeSectionInfo featured:(BOOL)featured;

- (void)reloadData NS_REQUIRES_SUPER;
- (BOOL)isEmpty;

@end

NS_ASSUME_NONNULL_END
