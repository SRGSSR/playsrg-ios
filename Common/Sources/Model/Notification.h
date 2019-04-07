//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <Foundation/Foundation.h>
#import <SRGDataProvider/SRGDataProvider.h>
#import <UserNotifications/UserNotifications.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Valid notification types
 */
typedef NS_ENUM(NSInteger, NotificationType) {
    /**
     *  Not specified.
     */
    NotificationTypeNone = 0,
    /**
     *  A (push notification) new on-demand content is available.
     */
    NotificationTypeNewOnDemandContentAvailable,
    /**
     *  A local new on-demand content is available.
     */
    NotificationTypeLocalNewOnDemandContentAvailable
};

/**
 *  Conversion between notification types and underlying string representations.
 */
OBJC_EXPORT NotificationType NotificationTypeFromString(NSString *notificationType);
OBJC_EXPORT NSString * NotificationTypeString(NotificationType notificationType);

/**
 *  Push notification information.
 */
@interface Notification : NSObject <SRGImageMetadata>

/**
 *  List of currently available notifications.
 */
@property (class, nonatomic, readonly) NSArray<Notification *> *notifications;

/**
 *  List of currently unread notifications.
 */
@property (class, nonatomic, readonly) NSArray<Notification *> *unreadNotifications;

/**
 *  Save a new notification or update an existing one.
 *
 *  @discussion A read notification cannot be marked as unread again.
 */
+ (void)saveNotification:(Notification *)notification read:(BOOL)read;

/**
 *  Remove a notification.
 */
+ (void)removeNotification:(Notification *)notification;

/**
 *  Create a notification from a system notification request.
 */
- (instancetype)initWithRequest:(UNNotificationRequest *)notificationRequest API_AVAILABLE(ios(10.0));

/**
 *  Create a notification from a system notification.
 */
- (instancetype)initWithNotification:(UNNotification *)notification API_AVAILABLE(ios(10.0));

/**
 *  The notification identifier.
 */
@property (nonatomic, readonly, copy) NSString *identifier;

/**
 *  The notification title.
 */
@property (nonatomic, readonly, copy) NSString *title;

/**
 *  The notification subtitle.
 */
@property (nonatomic, readonly, copy) NSString *body;

/**
 *  The URL of the image associated with the notification, if any.
 */
@property (nonatomic, readonly, nullable) NSURL *imageURL;

/**
 *  The date at which the notification was sent.
 */
@property (nonatomic, readonly) NSDate *date;

/**
 *  `YES` iff the notification has been read.
 */
@property (nonatomic, readonly, getter=isRead) BOOL read;

/**
 *  The type of the notification.
 */
@property (nonatomic, readonly) NotificationType type;

/**
 *  The URN of the media associated with the notification, if any.
 */
@property (nonatomic, readonly, copy, nullable) NSString *mediaURN;

/**
 *  The URN of the show associated with the notification, if any.
 */
@property (nonatomic, readonly, copy, nullable) NSString *showURN;

/**
 *  The identifier of the channel associated with the notification, if any.
 */
@property (nonatomic, readonly, copy, nullable) NSString *channelUid;

@end

NS_ASSUME_NONNULL_END
