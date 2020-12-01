//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

@import SRGDataProviderModel;
@import UIKit;

NS_ASSUME_NONNULL_BEGIN

@interface UILabel (PlaySRG)

/**
 *  Use this method to display the correct duration label for an object conform to a media metadata
 */
- (void)play_displayDurationLabelForMediaMetadata:(id<SRGMediaMetadata>)object;

/**
 *  Use this method to display the correct availability label for an object conform to a media metadata, if needed
 */
- (void)play_displayAvailabilityLabelForMediaMetadata:(id<SRGMediaMetadata>)object;

/**
*  Call to display the standard subtitle availability badge.
*/
- (void)play_setSubtitlesAvailableBadge;

/**
 *  Call to display the standard "web first" badge.
*/
- (void)play_setWebFirstBadge;

/**
 *  Call to display the standard "left" or "web first" badge.
*/
- (void)play_setAvailabilityBadgeForMediaMetadata:(id<SRGMediaMetadata>)object;

@end

NS_ASSUME_NONNULL_END
