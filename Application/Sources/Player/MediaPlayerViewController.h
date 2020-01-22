//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <CoconutKit/CoconutKit.h>
#import <SRGAnalytics/SRGAnalytics.h>
#import <SRGLetterbox/SRGLetterbox.h>

NS_ASSUME_NONNULL_BEGIN

OBJC_EXPORT NSString * const MediaPlayerViewControllerVisibilityDidChangeNotification;
OBJC_EXPORT NSString * const MediaPlayerViewControllerVisibleKey;

@interface MediaPlayerViewController : HLSViewController <SRGLetterboxViewDelegate, SRGLetterboxPictureInPictureDelegate, SRGAnalyticsViewTracking, UIGestureRecognizerDelegate, UIViewControllerTransitioningDelegate, NSUserActivityDelegate>

// Use nil for starting at the default location (resumes if the media is already being played)
- (instancetype)initWithURN:(NSString *)URN position:(nullable SRGPosition *)position fromPushNotification:(BOOL)fromPushNotification;
- (instancetype)initWithMedia:(SRGMedia *)media position:(nullable SRGPosition *)position fromPushNotification:(BOOL)fromPushNotification;
- (instancetype)initWithController:(SRGLetterboxController *)controller position:(nullable SRGPosition *)position fromPushNotification:(BOOL)fromPushNotification;

@property (nonatomic, readonly) SRGLetterboxController *letterboxController;

@end

@interface MediaPlayerViewController (Unavailable)

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
