//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "Notification.h"

#import "UIImage+PlaySRG.h"
#import "NSFileManager+PlaySRG.h"
#import "PlayLogger.h"

#import <libextobjc/libextobjc.h>
#import <Mantle/Mantle.h>

static NSString *NotificationDescriptionForType(NotificationType notificationType)
{
    static dispatch_once_t s_onceToken;
    static NSDictionary<NSNumber *, NSString *> *s_descriptions;
    dispatch_once(&s_onceToken, ^{
        s_descriptions = @{ @(NotificationTypeNewOnDemandContentAvailable) : @"New on-demand content available",
                            @(NotificationTypeLocalNewOnDemandContentAvailable) : @"Local new on-demand content available" };
    });
    return s_descriptions[@(notificationType)];
}

@interface Notification ()

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *body;
@property (nonatomic) NSURL *imageURL;
@property (nonatomic) NSDate *date;
@property (nonatomic, getter=isRead) BOOL read;
@property (nonatomic) NotificationType type;
@property (nonatomic, copy) NSString *mediaURN;
@property (nonatomic, copy) NSString *showURN;
@property (nonatomic, copy) NSString *channelUid;

@end

@implementation Notification

#pragma mark Class methods

+ (NSArray<Notification *> *)notifications
{
    NSMutableArray<Notification *> *notificationsArray = [NSMutableArray array];
    NSArray *notificationsPlistArray = [NSArray arrayWithContentsOfURL:[self notificationsFilePath]];
    [notificationsPlistArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:NSDictionary.class]) {
            NSDictionary *notificationDictionary = (NSDictionary *)obj;
            Notification *notification = [[Notification alloc] initWithDictionary:notificationDictionary];
            if (notification) {
                [notificationsArray addObject:notification];
            }
            else {
                PlayLogError(@"notifications", @"A notification could not be loaded and was skipped.");
            }
        }
    }];
    
    NSDate *currentDate = NSDate.date;
    NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
    [dateComponents setDay:-14];
    NSDate *fourteenDaysAgo = [NSCalendar.currentCalendar dateByAddingComponents:dateComponents toDate:currentDate options:0];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K >= %@", @keypath(Notification.new, date), fourteenDaysAgo];
    
    return [notificationsArray filteredArrayUsingPredicate:predicate];
}

+ (NSArray<Notification *> *)unreadNotifications
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(Notification.new, read), @NO];
    return [Notification.notifications filteredArrayUsingPredicate:predicate];
}

+ (void)saveNotification:(Notification *)notification read:(BOOL)read
{
    NSArray<Notification *> *notifications = [self notifications];
    
    NSInteger index = [notifications indexOfObject:notification];
    if (index != NSNotFound) {
        // Flag a notification unread again is not allowed.
        Notification *originalNotification = notifications[index];
        if (read && ! originalNotification.read) {
            notification.read = YES;
        }
        NSMutableArray<Notification *> *updatedNotifications = notifications.mutableCopy;
        [updatedNotifications replaceObjectAtIndex:index withObject:notification];
        notifications = updatedNotifications.copy;
    }
    else {
        notifications = [notifications arrayByAddingObject:notification];
    }
    
    NSSortDescriptor *dateSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(Notification.new, date) ascending:NO];
    NSSortDescriptor *identifierSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(Notification.new, identifier) ascending:NO];
    notifications = [notifications sortedArrayUsingDescriptors:@[dateSortDescriptor, identifierSortDescriptor]];
    [self saveNotifications:notifications];
}

+ (void)removeNotification:(Notification *)notification
{
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(Notification * _Nullable otherNotification, NSDictionary<NSString *,id> * _Nullable bindings) {
        return ! [notification isEqual:otherNotification];
    }];
    NSArray<Notification *> *notifications = [[self notifications] filteredArrayUsingPredicate:predicate];
    [self saveNotifications:notifications];
}

+ (NSURL *)notificationsFilePath
{
    return [[NSFileManager.play_applicationGroupContainerURL URLByAppendingPathComponent:@"Library"] URLByAppendingPathComponent:@"notifications.plist"];
}

+ (void)saveNotifications:(NSArray<Notification *> *)notifications
{
    NSMutableArray<NSDictionary *> *notificationsArray = [NSMutableArray array];
    [notifications enumerateObjectsUsingBlock:^(Notification * _Nonnull notification, NSUInteger idx, BOOL * _Nonnull stop) {
        [notificationsArray addObject:notification.dictionary];
    }];
    
    NSError *plistError = nil;
    NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:notificationsArray
                                                                   format:NSPropertyListXMLFormat_v1_0
                                                                  options:0
                                                                    error:&plistError];
    if (plistError) {
        PlayLogError(@"notifications", @"Could not save notifications data. Reason: %@", plistError);
        return;
    }
    
    NSError *writeError = nil;
    [plistData writeToURL:[self notificationsFilePath] options:NSDataWritingAtomic error:&writeError];
    if (writeError) {
        PlayLogError(@"notifications", @"Could not save notifications data. Reason: %@", writeError);
    }
}

#pragma mark Object lifecycle

- (instancetype)initWithRequest:(UNNotificationRequest *)notificationRequest
{
    return [self initWithRequest:notificationRequest date:NSDate.date];
}

- (instancetype)initWithNotification:(UNNotification *)notification
{
    return [self initWithRequest:notification.request date:notification.date];
}

- (instancetype)initWithRequest:(UNNotificationRequest *)notificationRequest date:(NSDate *)date API_AVAILABLE(ios(10.0))
{
    if (self = [super init]) {
        self.identifier = notificationRequest.identifier;
        self.date = date;
        
        self.title = notificationRequest.content.title ?: @"";
        self.body = notificationRequest.content.body;
        
        NSDictionary *userInfo = notificationRequest.content.userInfo;
        self.type = NotificationTypeFromString(userInfo[@"type"]);
        self.imageURL = (userInfo[@"imageUrl"]) ? [NSURL URLWithString:userInfo[@"imageUrl"]] : nil;
        self.mediaURN = userInfo[@"media"];
        self.showURN = userInfo[@"show"];
        self.channelUid = userInfo[@"channelId"];
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    if (self = [super init]) {
        self.identifier = dictionary[@"identifier"];
        self.date = dictionary[@"date"];
        self.read = [dictionary[@"read"] boolValue];
        
        self.title = dictionary[@"title"];
        self.body = dictionary[@"body"];
        
        self.type = NotificationTypeFromString(dictionary[@"type"]);
        self.imageURL = (dictionary[@"imageUrl"]) ? [NSURL URLWithString:dictionary[@"imageUrl"]] : nil;
        self.mediaURN = dictionary[@"media"];
        self.showURN = dictionary[@"show"];
        self.channelUid = dictionary[@"channelId"];
    }
    return self;
}

#pragma mark Getters and setters

- (NSDictionary *)dictionary
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    dictionary[@"identifier"] = self.identifier;
    dictionary[@"date"] = self.date;
    dictionary[@"read"] = @(self.read);
    
    dictionary[@"title"] = self.title;
    dictionary[@"body"] = self.body;
    
    dictionary[@"imageUrl"] = self.imageURL.absoluteString;
    dictionary[@"type"] = NotificationTypeString(self.type);
    dictionary[@"media"] = self.mediaURN;
    dictionary[@"show"] = self.showURN;
    dictionary[@"channelId"] = self.channelUid;
    return [dictionary copy];
}

#pragma mark SRGImageMetadata protocol

- (NSURL *)imageURLForDimension:(SRGImageDimension)dimension withValue:(CGFloat)value type:(NSString *)type
{
    NSString *dimensionString = (dimension == SRGImageDimensionWidth) ? @"width" : @"height";
    NSString *sizeComponent = [NSString stringWithFormat:@"scale/%@/%@", dimensionString, @(value)];
    return [self.imageURL URLByAppendingPathComponent:sizeComponent];
}

- (NSString *)imageTitle
{
    // Not saved in notifications
    return nil;
}

- (NSString *)imageCopyright
{
    // Not saved in notifications
    return nil;
}

#pragma mark Equality

- (BOOL)isEqual:(id)object
{
    if (! [object isKindOfClass:self.class]) {
        return NO;
    }
    
    Notification *otherNotification = object;
    return [self.identifier isEqualToString:otherNotification.identifier];
}

- (NSUInteger)hash
{
    return self.identifier.hash;
}

#pragma mark Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; identifier = %@; title = %@; date = %@; type: %@, read: %@>",
            self.class,
            self,
            self.identifier,
            self.title,
            self.date,
            NotificationDescriptionForType(self.type),
            self.read ? @"YES" : @"NO"];
}

@end

#pragma mark NotificationType transformations

static NSValueTransformer *NotificationTypeTransformer(void)
{
    static NSValueTransformer *s_transformer;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        s_transformer = [NSValueTransformer mtl_valueMappingTransformerWithDictionary:@{ @"newod" : @(NotificationTypeNewOnDemandContentAvailable),
                                                                                         @"localnewod" : @(NotificationTypeLocalNewOnDemandContentAvailable) }
                                                                         defaultValue:@(NotificationTypeNone)
                                                                  reverseDefaultValue:nil];
    });
    return s_transformer;
}

NotificationType NotificationTypeFromString(NSString *notificationType)
{
    return [[NotificationTypeTransformer() transformedValue:notificationType] integerValue];
}

NSString * NotificationTypeString(NotificationType notificationType)
{
    return [NotificationTypeTransformer() reverseTransformedValue:@(notificationType)];
}
