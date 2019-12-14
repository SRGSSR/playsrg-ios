//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <Foundation/Foundation.h>

#import "MenuItemInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface MenuSectionInfo : NSObject

/**
 *  Return the menu sections corresponding to the current configuration
 */
@property (class, nonatomic, readonly) NSArray<MenuSectionInfo *> *profileMenuSectionInfos;

/**
 *  Instantiate an entry describing a menu section
 *
 *  @param title         The title of the section
 *  @param menuItemInfos The items within the section
 *  @param headerless    If set to `YES`, the menu header will not be displayed, except when accessibility is used.
 */
- (instancetype)initWithTitle:(NSString *)title menuItemInfos:(NSArray<MenuItemInfo *> *)menuItemInfos headerless:(BOOL)headerless;

@property (nonatomic, readonly, copy, nullable) NSString *title;
@property (nonatomic, readonly) NSArray<MenuItemInfo *> *menuItemInfos;
@property (nonatomic, readonly, getter=isHeaderless) BOOL headerless;

@end

NS_ASSUME_NONNULL_END
