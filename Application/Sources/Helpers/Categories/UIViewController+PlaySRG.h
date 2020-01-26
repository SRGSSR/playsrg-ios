//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "Playlist.h"

#import <CoreMedia/CoreMedia.h>
#import <SRGDataProvider/SRGDataProvider.h>
#import <SRGLetterbox/SRGLetterbox.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Create and replace the shared playlist.
*/
OBJC_EXPORT Playlist *SharedPlaylistForURN(NSString *URN);

@interface UIViewController (PlaySRG)

/**
 *  Return the standard user interface orientations supported by the application. Useful when implementing the
 *  `-supportedInterfaceOrientations` of a view controller
 */
@property (class, nonatomic, readonly) UIInterfaceOrientationMask play_supportedInterfaceOrientations;

/**
 *  Convenience method to determine whether a view controller is appearing or disappearing. Take the parent view
 *  controller hierarchy in the process.
 *
 *  @discussion Must be called from -viewWill(Dis)Appear / -viewDid(Dis)Appear methods, otherwise the result is
 *              undefined
 */
- (BOOL)play_isMovingToParentViewController;
- (BOOL)play_isMovingFromParentViewController;

/**
 *  Same as `-setNeedsUpdateOfHomeIndicatorAutoHidden`, but fixing a UIKit crash. See http://www.openradar.me/35127134
 *  for more information. Does nothing on devices running on iOS 10 or earlier.
 *
 *  FIXME: Remove when possible. Might crash for people still running iOS 11 beta, see
 *         https://twitter.com/Javi/status/1064531698015133696.
 */
- (void)play_setNeedsUpdateOfHomeIndicatorAutoHidden;

/**
 *  The previewing context (peek) from which the view controller is presented, if any.
 */
@property (nonatomic, readonly, nullable) id<UIViewControllerPreviewing> play_previewingContext;

/**
 *  Play the specified media, presenting the appropriate media player based on the current context (whether Google Cast
 *  is enabled or not). The player is displayed modally, with the provided completion block called on completion. The
 *  player attempts to start at the specified position (use `nil` for the default location, resuming at the last playback
 *  location if available).
 *
 *  If the view controller implements the `PlaylistDataSource` protocol, an associated playlist will be attached
 *  accordingly.
 *
 *  On iOS 13 and above, AirPlay suggestions can be enabled so that the system, based on the user behavior, might offer
 *  a casting suggestion (https://developer.apple.com/videos/play/wwdc2019/501). On iOS 12 and below, this parameter is
 *  ignored.
 *
 *  The completion block is called when the media player has been presented (it will be called immediately if the
 *  player is readily visible).
 */
- (void)play_presentMediaPlayerWithMedia:(SRGMedia *)media
                                position:(nullable SRGPosition *)position
                      airPlaySuggestions:(BOOL)airPlaySuggestions
                    fromPushNotification:(BOOL)fromPushNotification
                                animated:(BOOL)animated
                              completion:(nullable void (^)(void))completion;

/**
 *  Same as `-play_presentMediaPlayerWithMedia:atPosition:fromPushNotification:animated:completion:`, but resuming from
 *  a Letterbox controller. Google Cast playback starts at the same position the controller was at.
 */
- (void)play_presentMediaPlayerFromLetterboxController:(SRGLetterboxController *)letterboxController
                                withAirPlaySuggestions:(BOOL)airPlaySuggestions
                                  fromPushNotification:(BOOL)fromPushNotification
                                              animated:(BOOL)animated
                                            completion:(nullable void (^)(void))completion;

@end

NS_ASSUME_NONNULL_END
