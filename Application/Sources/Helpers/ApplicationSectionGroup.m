//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "ApplicationSectionGroup.h"

#import "ApplicationConfiguration.h"

@interface ApplicationSectionGroup ()

@property (nonatomic, copy) NSString *title;
@property (nonatomic) NSArray<ApplicationSectionInfo *> *applicationSectionInfos;
@property (nonatomic, getter=isHeaderless) BOOL headerless;

@end

@implementation ApplicationSectionGroup

#pragma mark Class methods

+ (NSArray<ApplicationSectionGroup *> *)libraryApplicationSectionGroups
{
    ApplicationConfiguration *applicationConfiguration = ApplicationConfiguration.sharedApplicationConfiguration;
    
    NSMutableArray<ApplicationSectionGroup *> *sectionInfos = [NSMutableArray array];
    
    // My content section
    NSMutableArray<ApplicationSectionInfo *> *myContentApplicationSections = [NSMutableArray array];
    if (@available(iOS 10, *)) {
        [myContentApplicationSections addObject:[ApplicationSectionInfo applicationSectionInfoWithApplicationSection:ApplicationSectionNotifications]];
        
        NSArray<Notification *> *unreadNotifications = Notification.unreadNotifications;
        unreadNotifications = unreadNotifications.count > 3 ? @[ unreadNotifications[0], unreadNotifications[1], unreadNotifications[2] ] : unreadNotifications.count > 0 ? unreadNotifications : nil;
        for (Notification *notification in unreadNotifications) {
            [myContentApplicationSections addObject:[ApplicationSectionInfo applicationSectionInfoWithNotification:notification]];
        }
    }
    [myContentApplicationSections addObject:[ApplicationSectionInfo applicationSectionInfoWithApplicationSection:ApplicationSectionHistory]];
    [myContentApplicationSections addObject:[ApplicationSectionInfo applicationSectionInfoWithApplicationSection:ApplicationSectionFavorites]];
    [myContentApplicationSections addObject:[ApplicationSectionInfo applicationSectionInfoWithApplicationSection:ApplicationSectionWatchLater]];
    [myContentApplicationSections addObject:[ApplicationSectionInfo applicationSectionInfoWithApplicationSection:ApplicationSectionDownloads]];
    
    [sectionInfos addObject:[[ApplicationSectionGroup alloc] initWithTitle:NSLocalizedString(@"My content", @"Library section header label for user personal content")
                                                   applicationSectionInfos:myContentApplicationSections.copy
                                                                headerless:YES]];
    
    // Other item sections
    NSMutableArray<ApplicationSectionInfo *> *otherSectionInfos = [NSMutableArray array];
    if (applicationConfiguration.feedbackURL) {
        [otherSectionInfos addObject:[ApplicationSectionInfo applicationSectionInfoWithApplicationSection:ApplicationSectionFeedback]];
    }
    if (applicationConfiguration.impressumURL) {
        [otherSectionInfos addObject:[ApplicationSectionInfo applicationSectionInfoWithApplicationSection:ApplicationSectionHelp]];
    }
    if (otherSectionInfos.count > 0) {
        [sectionInfos addObject:[[ApplicationSectionGroup alloc] initWithTitle:NSLocalizedString(@"Miscellaneous", @"Miscellaneous library section header label")
                                                       applicationSectionInfos:otherSectionInfos.copy
                                                                    headerless:YES]];
    }
    
    return sectionInfos.copy;
}

#pragma Object lifecycle

- (instancetype)initWithTitle:(NSString *)title applicationSectionInfos:(NSArray<ApplicationSectionInfo *> *)applicationSectionInfos headerless:(BOOL)headerless
{
    if (self = [super init]) {
        self.title = title;
        self.applicationSectionInfos = applicationSectionInfos;
        self.headerless = headerless;
    }
    return self;
}

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return [self initWithTitle:@"" applicationSectionInfos:@[] headerless:YES];
}

#pragma mark Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; title = %@; applicationSectionInfos = %@>",
            self.class,
            self,
            self.title,
            self.applicationSectionInfos];
}

@end
