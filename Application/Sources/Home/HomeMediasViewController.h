//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "HomeSectionInfo.h"
#import "MediasViewController.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  View controller displaying a list of medias stemming from a home page.
 */
@interface HomeMediasViewController : MediasViewController

- (instancetype)initWithHomeSectionInfo:(HomeSectionInfo *)homeSectionInfo;

@property (nonatomic, readonly) HomeSectionInfo *homeSectionInfo;

@end

@interface HomeMediasViewController (Unavailable)

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
