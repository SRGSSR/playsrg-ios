//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "MenuSectionInfo.h"

#import "ApplicationConfiguration.h"

@interface MenuSectionInfo ()

@property (nonatomic, copy) NSString *title;
@property (nonatomic) NSArray<MenuItemInfo *> *menuItemInfos;
@property (nonatomic, getter=isHeaderless) BOOL headerless;

@end

@implementation MenuSectionInfo

#pragma mark Class methods

+ (NSArray<MenuSectionInfo *> *)profileMenuSectionInfos
{
    ApplicationConfiguration *applicationConfiguration = ApplicationConfiguration.sharedApplicationConfiguration;
    
    NSMutableArray<MenuSectionInfo *> *sectionInfos = [NSMutableArray array];
    
    // My content section
    NSMutableArray<MenuItemInfo *> *myContentMenuItems = [NSMutableArray array];
    if (@available(iOS 10, *)) {
        [myContentMenuItems addObject:[MenuItemInfo menuItemInfoWithMenuItem:MenuItemNotifications]];
    }
    [myContentMenuItems addObject:[MenuItemInfo menuItemInfoWithMenuItem:MenuItemHistory]];
    [myContentMenuItems addObject:[MenuItemInfo menuItemInfoWithMenuItem:MenuItemFavorites]];
    [myContentMenuItems addObject:[MenuItemInfo menuItemInfoWithMenuItem:MenuItemWatchLater]];
    [myContentMenuItems addObject:[MenuItemInfo menuItemInfoWithMenuItem:MenuItemDownloads]];
    
    [sectionInfos addObject:[[MenuSectionInfo alloc] initWithTitle:NSLocalizedString(@"My content", @"Menu section header label for user personal content")
                                                     menuItemInfos:myContentMenuItems.copy
                                                        headerless:YES]];
    
    // Other item sections
    NSMutableArray<MenuItemInfo *> *otherItemInfos = [NSMutableArray array];
    if (applicationConfiguration.feedbackURL) {
        [otherItemInfos addObject:[MenuItemInfo menuItemInfoWithMenuItem:MenuItemFeedback]];
    }
    if (applicationConfiguration.impressumURL) {
        [otherItemInfos addObject:[MenuItemInfo menuItemInfoWithMenuItem:MenuItemHelp]];
    }
    if (otherItemInfos.count > 0) {
        [sectionInfos addObject:[[MenuSectionInfo alloc] initWithTitle:NSLocalizedString(@"Miscellaneous", @"Miscellaneous menu section header label")
                                                         menuItemInfos:otherItemInfos.copy
                                                            headerless:YES]];
    }
    
    return sectionInfos.copy;
}

#pragma Object lifecycle

- (instancetype)initWithTitle:(NSString *)title menuItemInfos:(NSArray<MenuItemInfo *> *)menuItemInfos headerless:(BOOL)headerless
{
    if (self = [super init]) {
        self.title = title;
        self.menuItemInfos = menuItemInfos;
        self.headerless = headerless;
    }
    return self;
}

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return [self initWithTitle:@"" menuItemInfos:@[] headerless:YES];
}

#pragma mark Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; title = %@; menuItemInfos = %@>",
            self.class,
            self,
            self.title,
            self.menuItemInfos];
}

@end
