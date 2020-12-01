//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UILabel+PlaySRG.h"

#import "Layout.h"
#import "NSBundle+PlaySRG.h"
#import "NSDateFormatter+PlaySRG.h"
#import "NSString+PlaySRG.h"
#import "PlayDurationFormatter.h"
#import "SRGMedia+PlaySRG.h"
#import "UIColor+PlaySRG.h"

@import SRGAppearance;

static NSString *LabelFormattedDuration(NSTimeInterval duration)
{
    if (duration >= 60. * 60. * 24.) {
        static NSDateComponentsFormatter *s_dateComponentsFormatter;
        static dispatch_once_t s_onceToken;
        dispatch_once(&s_onceToken, ^{
            s_dateComponentsFormatter = [[NSDateComponentsFormatter alloc] init];
            s_dateComponentsFormatter.allowedUnits = NSCalendarUnitDay;
            s_dateComponentsFormatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
        });
        return [s_dateComponentsFormatter stringFromTimeInterval:duration];
    }
    else if (duration >= 60. * 60.) {
        static NSDateComponentsFormatter *s_dateComponentsFormatter;
        static dispatch_once_t s_onceToken;
        dispatch_once(&s_onceToken, ^{
            s_dateComponentsFormatter = [[NSDateComponentsFormatter alloc] init];
            s_dateComponentsFormatter.allowedUnits = NSCalendarUnitHour;
            s_dateComponentsFormatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
        });
        return [s_dateComponentsFormatter stringFromTimeInterval:duration];
    }
    else {
        return NSLocalizedString(@"less than 1 hour", @"Explains that a content has expired, will expire or will be available in less than one hour. Displayed in the media player view.");
    }
}

@implementation UILabel (PlaySRG)

#pragma mark Public

- (void)play_displayDurationLabelForMediaMetadata:(id<SRGMediaMetadata>)object
{
    BOOL isLivestreamOrScheduledLivestream = (object.contentType == SRGContentTypeLivestream || object.contentType == SRGContentTypeScheduledLivestream);
    [self play_displayDurationLabelWithTimeAvailability:[object timeAvailabilityAtDate:NSDate.date]
                                               duration:object.duration
                      isLivestreamOrScheduledLivestream:isLivestreamOrScheduledLivestream
                                            isLiveEvent:PlayIsSwissTXTURN(object.URN)];
}

- (void)play_displayAvailabilityLabelForMediaMetadata:(id<SRGMediaMetadata>)object
{
    self.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleBody];
    
    NSString *text = nil;
    UIColor *textColor = UIColor.play_grayColor;
    
    NSTimeInterval timeIntervalAfterEnd = PlayTimeIntervalAfterEnd(object);
    if (timeIntervalAfterEnd > DBL_MIN) {
        text = [NSString stringWithFormat:NSLocalizedString(@"Not available since %@", @"Explains that a content has expired (days or hours ago). Displayed in the media player view."), LabelFormattedDuration(timeIntervalAfterEnd)];
    }
    else {
        NSTimeInterval timeIntervalBeforeEnd = PlayTimeIntervalBeforeEnd(object);
        if (timeIntervalBeforeEnd > DBL_MIN) {
            text = [NSString stringWithFormat:NSLocalizedString(@"Still available for %@", @"Explains that a content is still online (for days or hours) but will expire. Displayed in the media player view."), LabelFormattedDuration(timeIntervalBeforeEnd)];
            textColor = UIColor.play_orangeColor;
        }
    }
    
    if (text) {
        self.text = text;
        self.textColor = textColor;
        self.hidden = NO;
    }
    else {
        self.text = nil;
        self.hidden = YES;
    }
}

- (void)play_setSubtitlesAvailableBadge
{
    [self play_setMediaBadgeWithString:NSLocalizedString(@"ST", @"Subtitles short label on media cells")];
    self.accessibilityLabel = PlaySRGAccessibilityLocalizedString(@"Subtitled", @"Accessibility label for the subtitled badge");
}

- (void)play_setWebFirstBadge
{
    self.backgroundColor = UIColor.srg_blueColor;
    self.layer.cornerRadius = LayoutStandardLabelCornerRadius;
    self.layer.masksToBounds = YES;
    self.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleCaption];
    self.text = [NSString stringWithFormat:@"  %@  ", NSLocalizedString(@"Web first", @"Web first label on media cells")].uppercaseString;
}

- (void)play_setAvailabilityBadgeForMediaMetadata:(id<SRGMediaMetadata>)object
{
    NSTimeInterval timeIntervalBeforeEnd = PlayTimeIntervalBeforeEnd(object);
    if (timeIntervalBeforeEnd > DBL_MIN && ! PlayIsWebFirst(object)) {
        [self play_setLeftBadgeWithRemainingTime:timeIntervalBeforeEnd];
    }
    else {
        [self play_setWebFirstBadge];
    }
}

#pragma mark Private

- (void)play_setLeftBadgeWithRemainingTime:(NSTimeInterval)remainingTime
{
    self.backgroundColor = UIColor.play_orangeColor;
    self.layer.cornerRadius = LayoutStandardLabelCornerRadius;
    self.layer.masksToBounds = YES;
    self.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleCaption];
    self.text = [NSString stringWithFormat:@" %@ ", LabelFormattedDuration(remainingTime).play_localizedUppercaseFirstLetterString];
}

- (void)play_displayDurationLabelWithTimeAvailability:(SRGTimeAvailability)timeAvailability duration:(NSTimeInterval)duration isLivestreamOrScheduledLivestream:(BOOL)isLivestreamOrScheduledLivestream isLiveEvent:(BOOL)isLiveEvent
{
    self.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleCaption];
    
    if (timeAvailability == SRGTimeAvailabilityNotYetAvailable) {
        [self play_displayDurationLabelWithName:NSLocalizedString(@"Soon", @"Short label identifying content which will be available soon.") isLive:NO];
    }
    else if (timeAvailability == SRGTimeAvailabilityNotAvailableAnymore) {
        [self play_displayDurationLabelWithName:NSLocalizedString(@"Expired", @"Short label identifying content which has expired.") isLive:NO];
    }
    else if (isLivestreamOrScheduledLivestream) {
        [self play_displayDurationLabelWithName:NSLocalizedString(@"Live", @"Short label identifying a livestream. Display in uppercase.") isLive:YES];
    }
    else if (isLiveEvent) {
        [self play_displayDurationLabelWithName:NSLocalizedString(@"Replay", @"Short label identifying a replay sport event. Display in uppercase.") isLive:NO];
    }
    else if (duration != 0.) {
        NSString *durationString = PlayFormattedDuration(duration / 1000.);
        [self play_displayDurationLabelWithName:durationString isLive:NO];
    }
    else {
        self.text = nil;
        self.hidden = YES;
    }
}

- (void)play_displayDurationLabelWithName:(NSString *)name isLive:(BOOL)isLive
{
    self.backgroundColor = isLive ? UIColor.play_liveRedColor : UIColor.play_blackDurationLabelBackgroundColor;
    self.layer.cornerRadius = LayoutStandardLabelCornerRadius;
    self.layer.masksToBounds = YES;
    
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"  %@  ", name].uppercaseString
                                                                                       attributes:@{ NSFontAttributeName : [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleCaption],
                                                                                                     NSForegroundColorAttributeName : UIColor.whiteColor }];
    self.attributedText = attributedText.copy;
    self.hidden = NO;
}

- (void)play_setMediaBadgeWithString:(NSString *)string
{
    self.backgroundColor = UIColor.play_whiteBadgeColor;
    self.layer.cornerRadius = LayoutStandardLabelCornerRadius;
    self.layer.masksToBounds = YES;
    self.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleCaption];
    self.text = [NSString stringWithFormat:@"  %@  ", string].uppercaseString;
    self.textColor = UIColor.blackColor;
}

@end
