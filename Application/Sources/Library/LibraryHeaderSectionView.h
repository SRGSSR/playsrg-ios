//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <UIKit/UIKit.h>

#import "ApplicationSectionGroup.h"

NS_ASSUME_NONNULL_BEGIN

@interface LibraryHeaderSectionView : UITableViewHeaderFooterView

+ (CGFloat)heightForApplicationSectionGroup:(ApplicationSectionGroup *)applicationSectionGroup;

@property (nonatomic) ApplicationSectionGroup *applicationSectionGroup;

@end

NS_ASSUME_NONNULL_END
