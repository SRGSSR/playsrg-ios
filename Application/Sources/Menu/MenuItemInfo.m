//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "MenuItemInfo.h"

#import "ApplicationConfiguration.h"

@interface MenuItemInfo ()

@property (nonatomic) MenuItem menuItem;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *uid;

@end

@implementation MenuItemInfo

#pragma Object lifecycle

+ (MenuItemInfo *)menuItemInfoWithMenuItem:(MenuItem)menuItem
{
    return [[MenuItemInfo alloc] initWithMenuItem:menuItem
                                            title:TitleForMenuItem(menuItem)];
}

+ (MenuItemInfo *)menuItemInfoWithRadioChannel:(RadioChannel *)radioChannel
{
    return [[MenuItemInfo alloc] initWithMenuItem:MenuItemRadio
                                            title:radioChannel.name
                                              uid:radioChannel.uid];
}

- (instancetype)initWithMenuItem:(MenuItem)menuItem title:(NSString *)title uid:(NSString *)uid
{
    if (self = [super init]) {
        self.menuItem = menuItem;
        self.title = title;
        self.uid = uid;
    }
    return self;
}

- (instancetype)initWithMenuItem:(MenuItem)menuItem title:(NSString *)title
{
    return [self initWithMenuItem:menuItem title:title uid:nil];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return [self initWithMenuItem:MenuItemUnknown title:@"" uid:nil];
}

#pragma clang diagnostic pop

#pragma mark Getters and setters

- (UIImage *)image
{
    UIImage *image = nil;
    switch (self.menuItem) {
        case MenuItemSearch: {
            image = [UIImage imageNamed:@"search-22"];
            break;
        }
            
        case MenuItemSubscriptions: {
            image = [UIImage imageNamed:@"subscriptions-22"];
            break;
        }
            
        case MenuItemWatchLater: {
            image = [UIImage imageNamed:@"watch_later-22"];
            break;
        }
            
        case MenuItemDownloads: {
            image = [UIImage imageNamed:@"download-22"];
            break;
        }
            
        case MenuItemHistory: {
            image = [UIImage imageNamed:@"history-22"];
            break;
        }
            
        case MenuItemTVOverview: {
            image = [UIImage imageNamed:@"home-22"];
            break;
        }
            
        case MenuItemTVByDate: {
            image = [UIImage imageNamed:@"calendar-22"];
            break;
        }
            
        case MenuItemTVShowAZ: {
            image = [UIImage imageNamed:@"atoz-22"];
            break;
        }
            
        case MenuItemRadio: {
            RadioChannel *radioChannel = [ApplicationConfiguration.sharedApplicationConfiguration radioChannelForUid:self.uid];
            image = RadioChannelLogo22Image(radioChannel);
            break;
        }
            
        case MenuItemRadioShowAZ: {
            image = [UIImage imageNamed:@"atoz-22"];
            break;
        }
            
        case MenuItemFeedback: {
            image = [UIImage imageNamed:@"feedback-22"];
            break;
        }
            
        case MenuItemSettings: {
            image = [UIImage imageNamed:@"settings-22"];
            break;
        }
            
        case MenuItemHelp: {
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
    if (self.menuItem == MenuItemRadio) {
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
    
    MenuItemInfo *otherMenuItemInfo = object;
    return (self.menuItem == otherMenuItemInfo.menuItem && (self.menuItem != MenuItemRadio || [self.uid isEqualToString:otherMenuItemInfo.uid]));
}

- (NSUInteger)hash
{
    return [NSString stringWithFormat:@"%@_%@", @(self.menuItem), self.uid].hash;
}

#pragma mark Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; menuItem = %@, title = %@, uid = %@>",
            self.class,
            self,
            @(self.menuItem),
            self.title,
            self.uid];
}

@end
