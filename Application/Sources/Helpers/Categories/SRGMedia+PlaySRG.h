//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

@import SRGDataProviderModel;

NS_ASSUME_NONNULL_BEGIN

// FIXME: Ask IL to get this information in a media
/**
 *  Return `YES` iff the URN is related to a live center event.
 */
OBJC_EXPORT BOOL PlayIsSwissTXTURN(NSString *URN);

OBJC_EXPORT BOOL PlayIsWebFirst(id<SRGMediaMetadata> object);
OBJC_EXPORT NSTimeInterval PlayTimeIntervalBeforeEnd(id<SRGMediaMetadata> object);
OBJC_EXPORT NSTimeInterval PlayTimeIntervalAfterEnd(id<SRGMediaMetadata> object);

@interface SRGMedia (PlaySRG)

@property (nonatomic, readonly, getter=play_isToday) BOOL play_today;

// Return a concatenation of lead and summary, iff summary not contains the lead, to avoid duplicate information. 
@property (nonatomic, readonly, nullable) NSString *play_fullSummary;

@property (nonatomic, readonly, getter=play_areSubtitlesAvailable) BOOL play_subtitlesAvailable;
@property (nonatomic, readonly, getter=play_isAudioDescriptionAvailable) BOOL play_audioDescriptionAvailable;
@property (nonatomic, readonly, getter=play_isMultiAudioAvailable) BOOL play_multiAudioAvailable;

@property (nonatomic, readonly, getter=play_isWebFirst) BOOL play_webFirst;

@property (nonatomic, readonly) NSArray<NSString *> *play_subtitleLanguages;
@property (nonatomic, readonly) NSArray<NSString *> *play_audioLanguages;

@end

NS_ASSUME_NONNULL_END
