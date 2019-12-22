//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <Foundation/Foundation.h>
#import <SRGDataProvider/SRGDataProvider.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Notitfication sent when a push notification has been received by the device.
 */
OBJC_EXPORT NSString * const PushServiceDidReceiveNotification;

/**
 *  Notitfication sent when the badge number has been changed on the device.
 */
OBJC_EXPORT NSString * const PushServiceBadgeDidChangeNotification;

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

@end

NS_ASSUME_NONNULL_END
