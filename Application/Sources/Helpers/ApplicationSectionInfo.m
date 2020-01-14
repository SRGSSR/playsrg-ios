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

+ (ApplicationSectionInfo *)applicationSectionInfoWithApplicationSection:(ApplicationSection)applicationSection
{
    return [self applicationSectionInfoWithApplicationSection:applicationSection options:nil];
}

+ (ApplicationSectionInfo *)applicationSectionInfoWithApplicationSection:(ApplicationSection)applicationSection options:(NSDictionary<ApplicationSectionOptionKey, id> *)options
{
    return [[ApplicationSectionInfo alloc] initWithApplicationSection:applicationSection
                                                                title:TitleForApplicationSection(applicationSection)
                                                              options:options];
}

+ (ApplicationSectionInfo *)applicationSectionInfoWithRadioChannel:(RadioChannel *)radioChannel
{
    return [self applicationSectionInfoWithRadioChannel:radioChannel options:nil];
}

+ (ApplicationSectionInfo *)applicationSectionInfoWithRadioChannel:(RadioChannel *)radioChannel options:(NSDictionary<ApplicationSectionOptionKey, id> *)options
{
    return [[ApplicationSectionInfo alloc] initWithApplicationSection:ApplicationSectionRadio
                                                                title:radioChannel.name
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

- (instancetype)initWithApplicationSection:(ApplicationSection)applicationSection title:(NSString *)title options:(NSDictionary<ApplicationSectionOptionKey, id> *)options
{
    return [self initWithApplicationSection:applicationSection title:title uid:nil options:options];
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
    UIImage *image = nil;
    switch (self.applicationSection) {
        case ApplicationSectionSearch: {
            image = [UIImage imageNamed:@"search-22"];
            break;
        }
            
        case ApplicationSectionFavorites: {
            image = [UIImage imageNamed:@"favorite-22"];
            break;
        }
            
        case ApplicationSectionWatchLater: {
            image = [UIImage imageNamed:@"watch_later-22"];
            break;
        }
            
        case ApplicationSectionDownloads: {
            image = [UIImage imageNamed:@"download-22"];
            break;
        }
            
        case ApplicationSectionHistory: {
            image = [UIImage imageNamed:@"history-22"];
            break;
        }
            
        case ApplicationSectionNotifications: {
            image = PushService.sharedService.enabled ? [UIImage imageNamed:@"subscription_full-22"] : [UIImage imageNamed:@"subscription-22"];
            break;
        }
            
        case ApplicationSectionTVOverview: {
            image = [UIImage imageNamed:@"home-22"];
            break;
        }
            
        case ApplicationSectionTVByDate: {
            image = [UIImage imageNamed:@"calendar-22"];
            break;
        }
            
        case ApplicationSectionTVShowAZ: {
            image = [UIImage imageNamed:@"atoz-22"];
            break;
        }
            
        case ApplicationSectionRadio: {
            RadioChannel *radioChannel = [ApplicationConfiguration.sharedApplicationConfiguration radioChannelForUid:self.uid];
            image = RadioChannelLogo22Image(radioChannel);
            break;
        }
            
        case ApplicationSectionRadioShowAZ: {
            image = [UIImage imageNamed:@"atoz-22"];
            break;
        }
            
        case ApplicationSectionFeedback: {
            image = [UIImage imageNamed:@"feedback-22"];
            break;
        }
            
        case ApplicationSectionSettings: {
            image = [UIImage imageNamed:@"settings-22"];
            break;
        }
            
        case ApplicationSectionHelp: {
            image = [UIImage imageNamed:@"help-22"];
            break;
        }
            
        default: {
            break;
        }
    }
    
    return image;
}

- (RadioChannel *)radioChannel
{
    if (self.applicationSection == ApplicationSectionRadio) {
        return [ApplicationConfiguration.sharedApplicationConfiguration radioChannelForUid:self.uid];
    }
    else {
        return nil;
    }
}

#pragma mark Equality

- (BOOL)isEqual:(id)object
{
    if (! [object isKindOfClass:self.class]) {
        return NO;
    }
    
    ApplicationSectionInfo *otherApplicationSectionInfo = object;
    return (self.applicationSection == otherApplicationSectionInfo.applicationSection && (self.applicationSection != ApplicationSectionRadio || [self.uid isEqualToString:otherApplicationSectionInfo.uid]));
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
