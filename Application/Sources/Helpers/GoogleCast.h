//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <SRGDataProvider/SRGDataProvider.h>
#import <SRGMediaPlayer/SRGMediaPlayer.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Notification sent when Google Cast playback is started from the device. Not received if the media changes on the
 *  receiver in another way.
 */
OBJC_EXPORT NSString * const GoogleCastPlaybackDidStartNotification;

/**
 *  The `SRGMedia` being played.
 */
OBJC_EXPORT NSString * const GoogleCastMediaKey;

/**
 *  Call to setup Google Cast.
 */
OBJC_EXPORT void GoogleCastSetup(void);

/**
 *  Return `YES` iff Google Cast is possible for the specified media composition.
 */
OBJC_EXPORT BOOL GoogleCastIsPossible(SRGMediaComposition *mediaComposition, NSError * _Nullable __autoreleasing * _Nullable pError);

/**
 *  Start Google Cast playback for the specified media composition, at the specified position. The
 *  `GoogleCastPlaybackDidStartNotification` notification is sent as well.
 */
OBJC_EXPORT BOOL GoogleCastPlayMediaComposition(SRGMediaComposition *mediaComposition, SRGPosition * _Nullable position, NSError * _Nullable __autoreleasing * _Nullable pError);

NS_ASSUME_NONNULL_END
