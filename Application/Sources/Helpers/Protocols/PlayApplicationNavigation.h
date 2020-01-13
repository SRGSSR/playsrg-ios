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
 *  Open an application section described by the provided information. If the section is supported by the class
 *  implementing this protocol, this method must be implemented to display the section and return `YES`. If the
 *  section is not supported the method must not display anything and return `NO`.
 */
- (BOOL)openApplicationSectionInfo:(ApplicationSectionInfo *)applicationSectionInfo;

@end

NS_ASSUME_NONNULL_END
