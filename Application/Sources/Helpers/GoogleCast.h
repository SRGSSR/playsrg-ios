//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <SRGDataProvider/SRGDataProvider.h>
#import <SRGMediaPlayer/SRGMediaPlayer.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Call to setup Google Cast.
 */
OBJC_EXPORT void GoogleCastSetup(void);

/**
 *  Return `YES` iff Google Cast is possible for the specified media composition.
 */
OBJC_EXPORT BOOL GoogleCastIsPossible(SRGMediaComposition *mediaComposition, NSError * _Nullable __autoreleasing * _Nullable pError);

OBJC_EXPORT BOOL GoogleCastPlayMediaComposition(SRGMediaComposition *mediaComposition, SRGPosition * _Nullable position, NSError * _Nullable __autoreleasing * _Nullable pError);

NS_ASSUME_NONNULL_END
