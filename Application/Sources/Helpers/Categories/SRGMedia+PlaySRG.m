//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGMedia+PlaySRG.h"

@import libextobjc;

@implementation SRGMedia (PlaySRG)

- (BOOL)play_isToday
{
    return [NSCalendar.currentCalendar isDateInToday:self.date];
}

- (NSString *)play_fullSummary
{
    if (self.lead.length && self.summary.length && ![self.summary containsString:self.lead]) {
        return [NSString stringWithFormat:@"%@\n\n%@", self.lead, self.summary];
    }
    else if (self.summary.length) {
        return self.summary;
    }
    else if (self.lead.length) {
        return self.lead;
    }
    else {
        return nil;
    }
}

- (BOOL)play_areSubtitlesAvailable
{
    return self.play_subtitleVariants.count != 0;
}

- (BOOL)play_isAudioDescriptionAvailable
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGVariant.new, type), @(SRGVariantTypeAudioDescription)];
    return [self.play_audioVariants filteredArrayUsingPredicate:predicate].count != 0;
}

- (BOOL)play_isMultiAudioAvailable
{
    NSArray<NSLocale *> *locales = [self.play_audioVariants valueForKey:@keypath(SRGVariant.new, locale)];
    return [NSSet setWithArray:locales].count > 1;
}

- (BOOL)play_isWebFirst
{
    return PlayIsWebFirst(self);
}

- (NSArray<NSString *> *)play_subtitleLanguages
{
    return [self.play_subtitleVariants valueForKeyPath:@keypath(SRGVariant.new, language)];
}

- (NSArray<NSString *> *)play_audioLanguages
{
    return [self.play_audioVariants valueForKeyPath:@keypath(SRGVariant.new, language)];
}

- (NSArray<SRGVariant *> *)play_subtitleVariants
{
    return [self subtitleVariantsForSource:self.recommendedSubtitleVariantSource];
}

- (NSArray<SRGVariant *> *)play_audioVariants
{
    return [self audioVariantsForSource:self.recommendedAudioVariantSource];
}

@end

#pragma mark Functions

BOOL PlayIsSwissTXTURN(NSString *mediaURN)
{
    return [mediaURN containsString:@":swisstxt:"];
}

BOOL PlayIsWebFirst(id<SRGMediaMetadata> object)
{
    NSDate *date = NSDate.date;
    SRGTimeAvailability timeAvailability = [object timeAvailabilityAtDate:date];
    return [object.date compare:date] == NSOrderedDescending && timeAvailability == SRGTimeAvailabilityAvailable && object.contentType == SRGContentTypeEpisode;
}

NSTimeInterval PlayTimeIntervalBeforeEnd(id<SRGMediaMetadata> object)
{
    NSDate *date = NSDate.date;
    SRGTimeAvailability timeAvailability = [object timeAvailabilityAtDate:date];
    if (timeAvailability == SRGTimeAvailabilityAvailable && object.endDate && object.contentType != SRGContentTypeScheduledLivestream && object.contentType != SRGContentTypeLivestream && object.contentType != SRGContentTypeTrailer) {
        NSDateComponents *monthsDateComponents = [NSCalendar.currentCalendar components:NSCalendarUnitDay fromDate:date toDate:object.endDate options:0];
        if (monthsDateComponents.day <= 30) {
            return [object.endDate timeIntervalSinceDate:date];
        }
    }
    return DBL_MIN;
}

NSTimeInterval PlayTimeIntervalAfterEnd(id<SRGMediaMetadata> object)
{
    NSDate *date = NSDate.date;
    SRGTimeAvailability timeAvailability = [object timeAvailabilityAtDate:date];
    if (timeAvailability == SRGTimeAvailabilityNotAvailableAnymore) {
        NSDate *endDate = object.endDate ?: [object.date dateByAddingTimeInterval:object.duration / 1000.];
        return [date timeIntervalSinceDate:endDate];
    }
    return DBL_MIN;
}
