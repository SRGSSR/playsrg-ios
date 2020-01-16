//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "ApplicationSectionGroup.h"

#import "ApplicationConfiguration.h"
#import "PushService.h"

@interface ApplicationSectionGroup ()

@property (nonatomic, copy) NSString *title;
@property (nonatomic) NSArray<ApplicationSectionInfo *> *sectionInfos;

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
        if (PushService.sharedService.enabled) {
            [myContentApplicationSections addObject:[ApplicationSectionInfo applicationSectionInfoWithApplicationSection:ApplicationSectionNotifications]];
            
            NSArray<Notification *> *unreadNotifications = Notification.unreadNotifications;
            NSArray<Notification *> *previewNotifications = [unreadNotifications subarrayWithRange:NSMakeRange(0, MIN(3, unreadNotifications.count))];
            for (Notification *notification in previewNotifications) {
                [myContentApplicationSections addObject:[ApplicationSectionInfo applicationSectionInfoWithNotification:notification]];
            }
        }
    }
    [myContentApplicationSections addObject:[ApplicationSectionInfo applicationSectionInfoWithApplicationSection:ApplicationSectionHistory]];
    [myContentApplicationSections addObject:[ApplicationSectionInfo applicationSectionInfoWithApplicationSection:ApplicationSectionFavorites]];
    [myContentApplicationSections addObject:[ApplicationSectionInfo applicationSectionInfoWithApplicationSection:ApplicationSectionWatchLater]];
    [myContentApplicationSections addObject:[ApplicationSectionInfo applicationSectionInfoWithApplicationSection:ApplicationSectionDownloads]];
    
    [sectionInfos addObject:[[ApplicationSectionGroup alloc] initWithTitle:NSLocalizedString(@"My content", @"Library group header label for user personal content")
                                                              sectionInfos:myContentApplicationSections.copy]];
    
    // Other item sections
    NSMutableArray<ApplicationSectionInfo *> *otherSectionInfos = [NSMutableArray array];
    if (applicationConfiguration.feedbackURL) {
        [otherSectionInfos addObject:[ApplicationSectionInfo applicationSectionInfoWithApplicationSection:ApplicationSectionFeedback]];
    }
    if (applicationConfiguration.impressumURL) {
        [otherSectionInfos addObject:[ApplicationSectionInfo applicationSectionInfoWithApplicationSection:ApplicationSectionHelp]];
    }
    if (otherSectionInfos.count > 0) {
        [sectionInfos addObject:[[ApplicationSectionGroup alloc] initWithTitle:NSLocalizedString(@"Miscellaneous", @"Miscellaneous library group header label")
                                                                  sectionInfos:otherSectionInfos.copy]];
    }
    
    return sectionInfos.copy;
}

#pragma Object lifecycle

/**
 *  Instantiate a group.
 *
 *  @param title        The title of the group
 *  @param sectionInfos The items within the group
 */
- (instancetype)initWithTitle:(NSString *)title sectionInfos:(NSArray<ApplicationSectionInfo *> *)sectionInfos
{
    if (self = [super init]) {
        self.title = title;
        self.sectionInfos = sectionInfos;
    }
    return self;
}

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return [self initWithTitle:@"" sectionInfos:@[]];
}

#pragma mark Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; title = %@; sectionInfos = %@>",
            self.class,
            self,
            self.title,
            self.sectionInfos];
}

@end
