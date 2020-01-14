//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <Foundation/Foundation.h>

#import "ApplicationSectionInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface ApplicationSectionGroup : NSObject

/**
 *  Return the library section groups corresponding to the current configuration.
 */
@property (class, nonatomic, readonly) NSArray<ApplicationSectionGroup *> *libraryApplicationSectionGroups;

@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly) NSArray<ApplicationSectionInfo *> *sectionInfos;

@end

NS_ASSUME_NONNULL_END
