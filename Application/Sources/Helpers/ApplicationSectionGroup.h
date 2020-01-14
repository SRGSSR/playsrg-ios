//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "ApplicationSectionInfo.h"

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Groups several sections of the application.
 */
@interface ApplicationSectionGroup : NSObject

/**
 *  Return the library section groups corresponding to the current configuration.
 */
@property (class, nonatomic, readonly) NSArray<ApplicationSectionGroup *> *libraryApplicationSectionGroups;

/**
 *  Properties.
 */
@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly) NSArray<ApplicationSectionInfo *> *sectionInfos;

@end

NS_ASSUME_NONNULL_END
