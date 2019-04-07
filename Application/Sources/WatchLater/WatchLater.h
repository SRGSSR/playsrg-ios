//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <SRGDataProvider/SRGDataProvider.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Return `YES` if the media is in the watch later list.
 *
 *  @discussion Must be called from the main thread
 */

OBJC_EXPORT BOOL WatchLaterContainsMediaMetadata(id<SRGMediaMetadata> _Nonnull mediaMetadata);

/**
 *  Add a media to the watch later list.
 *
 *  @discussion Must be called from the main thread. The completion block is called on the main thread.
 */
OBJC_EXPORT void WatchLaterAddMediaMetadata(id<SRGMediaMetadata> _Nonnull mediaMetadata, void (^completion)(NSError * _Nullable error));

/**
 *  Remove a media to the watch later list.
 *
 *  @discussion Must be called from the main thread. The completion block is called on the main thread.
 */
OBJC_EXPORT void WatchLaterRemoveMediaMetadata(id<SRGMediaMetadata> _Nonnull mediaMetadata, void (^completion)(NSError * _Nullable error));

/**
 *  Toggle a media to the watch later list.
 *
 *  @discussion Must be called from the main thread. The completion block is called on the main thread.
 */
OBJC_EXPORT void WatchLaterToggleMediaMetadata(id<SRGMediaMetadata> _Nonnull mediaMetadata, void (^completion)(BOOL added, NSError * _Nullable error));

/**
 *  Perform migration.
 */
OBJC_EXPORT void WatchLaterMigrate();

NS_ASSUME_NONNULL_END
