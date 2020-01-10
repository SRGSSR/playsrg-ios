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
 *  Return the library section group corresponding to the current configuration
 */
@property (class, nonatomic, readonly) NSArray<ApplicationSectionGroup *> *libraryApplicationSectionGroups;

/**
 *  Instantiate an entry describing a librbary section
 *
 *  @param title         The title of the section
 *  @param applicationSectionInfos The items within the section
 *  @param headerless    If set to `YES`, the section header will not be displayed, except when accessibility is used.
 */
- (instancetype)initWithTitle:(NSString *)title applicationSectionInfos:(NSArray<ApplicationSectionInfo *> *)applicationSectionInfos headerless:(BOOL)headerless;

@property (nonatomic, readonly, copy, nullable) NSString *title;
@property (nonatomic, readonly) NSArray<ApplicationSectionInfo *> *applicationSectionInfos;
@property (nonatomic, readonly, getter=isHeaderless) BOOL headerless;

@end

NS_ASSUME_NONNULL_END
