//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "ApplicationSectionInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Common protocol for view controllers supporting application navigation.
 */
@protocol PlayApplicationNavigation <NSObject>

/**
 *  Supported application sections.
 */
@property (nonatomic, readonly) NSArray<NSNumber *> *supportedApplicationSections;

/**
 *  Open the application section.
 */
- (void)openApplicationSectionInfo:(ApplicationSectionInfo *)applicationSectionInfo;

@end

NS_ASSUME_NONNULL_END
