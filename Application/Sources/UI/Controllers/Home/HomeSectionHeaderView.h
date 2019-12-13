//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <UIKit/UIKit.h>

#import "HomeSectionInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface HomeSectionHeaderView : UITableViewHeaderFooterView

+ (CGFloat)heightForHomeSectionInfo:(HomeSectionInfo *)homeSectionInfo bounds:(CGRect)bounds featured:(BOOL)featured;

@property (nonatomic, readonly, nullable) HomeSectionInfo *homeSectionInfo;
@property (nonatomic, readonly, getter=isFeatured) BOOL featured;

- (void)setHomeSectionInfo:(nullable HomeSectionInfo *)homeSectionInfo featured:(BOOL)featured;

@end

NS_ASSUME_NONNULL_END
