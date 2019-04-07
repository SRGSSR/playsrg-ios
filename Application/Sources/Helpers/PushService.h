//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <Foundation/Foundation.h>
#import <SRGDataProvider/SRGDataProvider.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Notification sent when a subscription state changes (added or removed). Use associated keys to retrieve information
 *  about the change.
 */
OBJC_EXPORT NSString * const PushServiceSubscriptionStateDidChangeNotification;                                         // Notification name
OBJC_EXPORT NSString * const PushServiceSubscriptionObjectKey;                                                          // Object subscribed to / from
OBJC_EXPORT NSString * const PushServiceSubscriptionStateKey;                                                           // Key to access the current subscription state as a `BOOL` (wrapped as an `NSNumber`)

/**
 *  Notitfication sent when a push notification has been received by the device.
 */
OBJC_EXPORT NSString * const PushServiceDidReceiveNotification;

/**
 *  Service for push notifications.
 */
@interface PushService : NSObject

/**
 *  Perform push notification setup.
 *
 *  @discussion This method must be called from `-application:didFinishLaunchingWithOptions:`, otherwise the behavior
 *              is undefined.
 */
- (void)setup;

/**
 *  Service singleton. `nil` if push notifications are not available for the application.
 */
@property (class, nonatomic, readonly, nullable) PushService *sharedService;

/**
 *  Return `YES` iff push notifications are enabled in the system settings.
 */
@property (nonatomic, readonly, getter=isEnabled) BOOL enabled;

/**
 *  Attempt to present the system alert to enable push notifications. Returns `YES` iff presented.
 */
- (BOOL)presentSystemAlertForPushNotifications;

/**
 *  Reset the application badge on the Springboard.
 */
- (void)resetApplicationBadge;

/**
 *  Update the application badge on the Springboard.
 */
- (void)updateApplicationBadge;

/**
 *  Toggle subscription for the specified show.
 */
- (BOOL)toggleSubscriptionForShow:(SRGShow *)show;

/**
 *  Toggle Push notification subscription for the specified show.
 */
- (BOOL)togglePushNotificationForShow:(SRGShow *)show;

/**
 *  Remove any subscription for the specified show.
 */
- (BOOL)unsubscribeFromShow:(SRGShow *)show;

/**
 *  Return YES iff the user has subscribed to the specified show.
 */
- (BOOL)isSubscribedToShow:(SRGShow *)show;

/**
 *  Return YES iff the user has subscribed push notification to the specified show.
 */
- (BOOL)isPushNotificationSubscribedToShow:(SRGShow *)show;

/**
 *  Return the URNs of all shows the user has subscribed to.
 */
@property (nonatomic, readonly) NSArray<NSString *> *subscribedShowURNs;

@end

@interface PushService (Helpers)

- (BOOL)toggleSubscriptionForShow:(SRGShow *)show inView:(nullable UIView *)view;
- (BOOL)toggleSubscriptionForShow:(SRGShow *)show inViewController:(nullable UIViewController *)viewController;

- (BOOL)togglePushNotificationForShow:(SRGShow *)show inView:(nullable UIView *)view;
- (BOOL)togglePushNotificationForShow:(SRGShow *)show inViewController:(nullable UIViewController *)viewController;

- (void)migrate;

@end

NS_ASSUME_NONNULL_END
