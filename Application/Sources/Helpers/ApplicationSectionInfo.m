//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "ApplicationSectionInfo.h"

#import "ApplicationConfiguration.h"
#import "PushService.h"

ApplicationSectionOptionKey const ApplicationSectionOptionNotificationKey = @"ApplicationSectionOptionNotification";
ApplicationSectionOptionKey const ApplicationSectionOptionSearchMediaTypeOptionKey = @"ApplicationSectionOptionSearchMediaTypeOption";
ApplicationSectionOptionKey const ApplicationSectionOptionSearchQueryKey = @"ApplicationSectionOptionSearchQuery";
ApplicationSectionOptionKey const ApplicationSectionOptionShowAZIndexKey = @"ApplicationSectionOptionShowAZIndex";
ApplicationSectionOptionKey const ApplicationSectionOptionShowByDateDateKey = @"ApplicationSectionOptionShowByDateDate";

@interface ApplicationSectionInfo ()

@property (nonatomic) ApplicationSection applicationSection;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *uid;

@property (nonatomic) NSDictionary<ApplicationSectionOptionKey, id> *options;

@end

@implementation ApplicationSectionInfo

#pragma mark Class methods

+ (ApplicationSectionInfo *)applicationSectionInfoWithApplicationSection:(ApplicationSection)applicationSection radioChannel:(RadioChannel *)radioChannel
{
    return [self applicationSectionInfoWithApplicationSection:applicationSection radioChannel:radioChannel options:nil];
}

+ (ApplicationSectionInfo *)applicationSectionInfoWithApplicationSection:(ApplicationSection)applicationSection radioChannel:(RadioChannel *)radioChannel options:(NSDictionary<ApplicationSectionOptionKey, id> *)options
{
    return [[ApplicationSectionInfo alloc] initWithApplicationSection:applicationSection
                                                                title:TitleForApplicationSection(applicationSection)
                                                                  uid:radioChannel.uid
                                                              options:options];
}

+ (ApplicationSectionInfo *)applicationSectionInfoWithNotification:(Notification *)notification
{
    return [[ApplicationSectionInfo alloc] initWithApplicationSection:ApplicationSectionNotifications
                                                                title:notification.title
                                                                  uid:notification.identifier
                                                              options:@{ ApplicationSectionOptionNotificationKey : notification }];
}

+ (NSArray<ApplicationSectionInfo *> *)libraryApplicationSectionInfos
{
    NSMutableArray<ApplicationSectionInfo *> *sectionInfos = [NSMutableArray array];
    if (@available(iOS 10, *)) {
        if (PushService.sharedService.enabled) {
            [sectionInfos addObject:[self applicationSectionInfoWithApplicationSection:ApplicationSectionNotifications radioChannel:nil]];
            
            NSArray<Notification *> *unreadNotifications = Notification.unreadNotifications;
            NSArray<Notification *> *previewNotifications = [unreadNotifications subarrayWithRange:NSMakeRange(0, MIN(3, unreadNotifications.count))];
            for (Notification *notification in previewNotifications) {
                [sectionInfos addObject:[self applicationSectionInfoWithNotification:notification]];
            }
        }
    }
    [sectionInfos addObject:[self applicationSectionInfoWithApplicationSection:ApplicationSectionHistory radioChannel:nil]];
    [sectionInfos addObject:[self applicationSectionInfoWithApplicationSection:ApplicationSectionFavorites radioChannel:nil]];
    [sectionInfos addObject:[self applicationSectionInfoWithApplicationSection:ApplicationSectionWatchLater radioChannel:nil]];
    [sectionInfos addObject:[self applicationSectionInfoWithApplicationSection:ApplicationSectionDownloads radioChannel:nil]];
    
    return sectionInfos.copy;
}

#pragma Object lifecycle

- (instancetype)initWithApplicationSection:(ApplicationSection)applicationSection title:(NSString *)title uid:(NSString *)uid options:(NSDictionary<ApplicationSectionOptionKey, id> *)options
{
    if (self = [super init]) {
        self.applicationSection = applicationSection;
        self.title = title;
        self.uid = uid;
        self.options = options;
    }
    return self;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return [self initWithApplicationSection:ApplicationSectionUnknown title:@"" uid:nil options:nil];
}

#pragma clang diagnostic pop

#pragma mark Getters and setters

- (UIImage *)image
{
    switch (self.applicationSection) {
        case ApplicationSectionSearch: {
            return [UIImage imageNamed:@"search-22"];
            break;
        }
            
        case ApplicationSectionFavorites: {
            return [UIImage imageNamed:@"favorite-22"];
            break;
        }
            
        case ApplicationSectionWatchLater: {
            return [UIImage imageNamed:@"watch_later-22"];
            break;
        }
            
        case ApplicationSectionDownloads: {
            return [UIImage imageNamed:@"download-22"];
            break;
        }
            
        case ApplicationSectionHistory: {
            return [UIImage imageNamed:@"history-22"];
            break;
        }
            
        case ApplicationSectionNotifications: {
            return PushService.sharedService.enabled ? [UIImage imageNamed:@"subscription_full-22"] : [UIImage imageNamed:@"subscription-22"];
            break;
        }
            
        case ApplicationSectionOverview: {
            return [UIImage imageNamed:@"home-22"];
            break;
        }
            
        case ApplicationSectionShowByDate: {
            return [UIImage imageNamed:@"calendar-22"];
            break;
        }
            
        case ApplicationSectionShowAZ: {
            return [UIImage imageNamed:@"atoz-22"];
            break;
        }
            
        case ApplicationSectionRadioLive: {
            RadioChannel *radioChannel = [ApplicationConfiguration.sharedApplicationConfiguration radioChannelForUid:self.uid];
            return RadioChannelLogo22Image(radioChannel);
            break;
        }
            
        default: {
            return nil;
            break;
        }
    }
}

- (RadioChannel *)radioChannel
{
    return [ApplicationConfiguration.sharedApplicationConfiguration radioChannelForUid:self.uid];
}

#pragma mark Equality

- (BOOL)isEqual:(id)object
{
    if (! [object isKindOfClass:self.class]) {
        return NO;
    }
    
    ApplicationSectionInfo *otherApplicationSectionInfo = object;
    return self.applicationSection == otherApplicationSectionInfo.applicationSection && (self.uid == otherApplicationSectionInfo.uid || [self.uid isEqual:otherApplicationSectionInfo.uid]);
}

- (NSUInteger)hash
{
    return [NSString stringWithFormat:@"%@_%@", @(self.applicationSection), self.uid].hash;
}

#pragma mark Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; applicationSection = %@, title = %@, uid = %@>",
            self.class,
            self,
            @(self.applicationSection),
            self.title,
            self.uid];
}

@end
