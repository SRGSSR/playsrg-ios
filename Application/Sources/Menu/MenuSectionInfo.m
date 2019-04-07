//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "MenuSectionInfo.h"

#import "ApplicationConfiguration.h"
#import "PushService.h"

@interface MenuSectionInfo ()

@property (nonatomic, copy) NSString *title;
@property (nonatomic) NSArray<MenuItemInfo *> *menuItemInfos;
@property (nonatomic, getter=isHeaderless) BOOL headerless;

@end

@implementation MenuSectionInfo

#pragma mark Class methods

+ (NSArray<MenuSectionInfo *> *)currentMenuSectionInfos
{
    ApplicationConfiguration *applicationConfiguration = ApplicationConfiguration.sharedApplicationConfiguration;
    
    NSMutableArray<MenuSectionInfo *> *sectionInfos = [NSMutableArray array];
    
    // General section
    if (applicationConfiguration.searchOptions.count != 0) {
        [sectionInfos addObject:[[MenuSectionInfo alloc] initWithTitle:NSLocalizedString(@"General", @"General menu section header label")
                                                         menuItemInfos:@[[MenuItemInfo menuItemInfoWithMenuItem:MenuItemSearch]]
                                                            headerless:YES]];
    }
    
    // My content section
    NSMutableArray<MenuItemInfo *> *myContentMenuItems = [NSMutableArray array];
    [myContentMenuItems addObject:[MenuItemInfo menuItemInfoWithMenuItem:MenuItemHistory]];
    if (PushService.sharedService) {
        [myContentMenuItems addObject:[MenuItemInfo menuItemInfoWithMenuItem:MenuItemSubscriptions]];
    }
    [myContentMenuItems addObject:[MenuItemInfo menuItemInfoWithMenuItem:MenuItemWatchLater]];
    [myContentMenuItems addObject:[MenuItemInfo menuItemInfoWithMenuItem:MenuItemDownloads]];
    
    [sectionInfos addObject:[[MenuSectionInfo alloc] initWithTitle:NSLocalizedString(@"My content", @"Menu section header label for user personal content")
                                                     menuItemInfos:[myContentMenuItems copy]
                                                        headerless:YES]];
    
    // TV section
    NSArray *tvMenuItems = applicationConfiguration.tvMenuItems;
    if (tvMenuItems.count != 0) {
        NSMutableArray *menuItemInfos = [NSMutableArray new];
        
        for (NSNumber *menuItemNumber in tvMenuItems) {
            MenuItem menuItem = menuItemNumber.integerValue;
            if (menuItem == MenuItemUnknown) {
                continue;
            }
            
            MenuItemInfo *menuItemInfo = [MenuItemInfo menuItemInfoWithMenuItem:menuItem];
            [menuItemInfos addObject:menuItemInfo];
        }
        
        if (menuItemInfos.count != 0) {
            [sectionInfos addObject:[[MenuSectionInfo alloc] initWithTitle:NSLocalizedString(@"TV", @"TV menu section header label")
                                                             menuItemInfos:[menuItemInfos copy]
                                                                headerless:NO]];
        }
    }
    
    // Radio section
    NSArray *radioChannels = applicationConfiguration.radioChannels;
    if (radioChannels.count != 0) {
        NSMutableArray *menuItemInfos = [NSMutableArray new];
        
        NSArray *radioMenuItems = applicationConfiguration.radioMenuItems;
        for (NSNumber *menuItemNumber in radioMenuItems) {
            MenuItem menuItem = menuItemNumber.integerValue;
            if (menuItem == MenuItemUnknown) {
                continue;
            }
            
            MenuItemInfo *menuItemInfo = [MenuItemInfo menuItemInfoWithMenuItem:menuItem];
            [menuItemInfos addObject:menuItemInfo];
        }
        
        for (RadioChannel *radioChannel in radioChannels) {
            MenuItemInfo *menuItemInfo = [MenuItemInfo menuItemInfoWithRadioChannel:radioChannel];
            [menuItemInfos addObject:menuItemInfo];
        }
        
        if (menuItemInfos.count != 0) {
            [sectionInfos addObject:[[MenuSectionInfo alloc] initWithTitle:NSLocalizedString(@"Radio", @"Radio menu section header label")
                                                             menuItemInfos:[menuItemInfos copy]
                                                                headerless:NO]];
        }
    }
    
    // Other item sections
    NSMutableArray<MenuItemInfo *> *otherItemInfos = [NSMutableArray array];
    if (applicationConfiguration.feedbackURL) {
        [otherItemInfos addObject:[MenuItemInfo menuItemInfoWithMenuItem:MenuItemFeedback]];
    }
    
    [otherItemInfos addObject:[MenuItemInfo menuItemInfoWithMenuItem:MenuItemSettings]];
    
    if (applicationConfiguration.impressumURL) {
        [otherItemInfos addObject:[MenuItemInfo menuItemInfoWithMenuItem:MenuItemHelp]];
    }
    [sectionInfos addObject:[[MenuSectionInfo alloc] initWithTitle:NSLocalizedString(@"Miscellaneous", @"Miscellaneous menu section header label")
                                                     menuItemInfos:[otherItemInfos copy]
                                                        headerless:YES]];
    
    return [sectionInfos copy];
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
