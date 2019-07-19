//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UILabel+PlaySRG.h"

#import "NSBundle+PlaySRG.h"
#import "NSDateFormatter+PlaySRG.h"
#import "PlayDateComponentsFormatter.h"
#import "SRGMedia+PlaySRG.h"
#import "UIColor+PlaySRG.h"

#import <SRGAppearance/SRGAppearance.h>

@interface UIFont (SRGLetterbox_Private)

+ (UIFont *)srg_awesomeFontWithTextStyle:(NSString *)textStyle;

@end

@implementation UILabel (PlaySRG)

#pragma mark Public

- (void)play_displayDurationLabelForLive
{
    [self play_displayDurationLabelWithName:NSLocalizedString(@"Live", @"Short label identifying a livestream. Display in uppercase.") bulletColor:UIColor.play_liveRedColor];
}

- (void)play_displayDurationLabelForMediaMetadata:(id<SRGMediaMetadata>)object
{
    BOOL isLivestream = (object.contentType == SRGContentTypeLivestream || object.contentType == SRGContentTypeScheduledLivestream);
    SRGTimeAvailability timeAvailability = [object timeAvailabilityAtDate:NSDate.date];
    
    self.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleCaption];
    
    if (timeAvailability == SRGTimeAvailabilityNotYetAvailable) {
        [self play_displayDurationLabelWithName:NSLocalizedString(@"Soon", @"Short label identifying content which will be available soon.") bulletColor:isLivestream ? UIColor.whiteColor : nil];
    }
    else if (timeAvailability == SRGTimeAvailabilityNotAvailableAnymore) {
        [self play_displayDurationLabelWithName:NSLocalizedString(@"Expired", @"Short label identifying content which has expired.") bulletColor:nil];
    }
    else if (isLivestream) {
        [self play_displayDurationLabelForLive];
    }
    else if(PlayIsSwissTXTURN(object.URN)) {
        [self play_displayDurationLabelWithName:NSLocalizedString(@"Replay", @"Short label identifying a replay sport event. Display in uppercase.") bulletColor:[UIColor srg_blueColor]];
    }
    else if([object.date compare:NSDate.date] == NSOrderedDescending) {
        [self play_displayDurationLabelWithName:NSLocalizedString(@"Web first", @"Short label identifying a web first content. Display in uppercase.") bulletColor:[UIColor srg_blueColor]];
    }
    else if (object.duration != 0.) {
        NSString *durationString = PlayFormattedDuration(object.duration / 1000.);
        [self play_displayDurationLabelWithName:durationString bulletColor:nil];
    }
    else {
        self.text = nil;
        self.hidden = YES;
    }
}

- (void)play_displayAvailabilityLabelForMediaMetadata:(id<SRGMediaMetadata>)object
{
    self.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleBody];
    
    NSString *text = nil;
    NSDate *nowDate = NSDate.date;
    SRGTimeAvailability timeAvailability = [object timeAvailabilityAtDate:nowDate];
    if (timeAvailability == SRGTimeAvailabilityNotAvailableAnymore) {
        NSDate *endDate = object.endDate ?: [object.date dateByAddingTimeInterval:object.duration / 1000.];
        NSTimeInterval timeIntervalAfterEnd = [nowDate timeIntervalSinceDate:endDate];
        text = [NSString stringWithFormat:NSLocalizedString(@"Not available since %@", @"Explains that a content has expired (days or hours ago). Displayed in the media player view."), PlayShortFormattedDuration(timeIntervalAfterEnd)];
    }
    else if (timeAvailability == SRGTimeAvailabilityAvailable && object.endDate && object.contentType != SRGContentTypeScheduledLivestream && object.contentType != SRGContentTypeLivestream) {
        NSDateComponents *monthsDateComponents = [NSCalendar.currentCalendar components:NSCalendarUnitDay fromDate:nowDate toDate:object.endDate options:0];
        if (monthsDateComponents.day <= 30) {
            NSTimeInterval timeIntervalBeforeEnd = [object.endDate timeIntervalSinceDate:nowDate];
            text = [NSString stringWithFormat:NSLocalizedString(@"Still available for %@", @"Explains that a content is still online (for days or hours) but will expire. Displayed in the media player view."), PlayShortFormattedDuration(timeIntervalBeforeEnd)];
        }
    }
    
    if (text) {
        self.text = text;
        self.hidden = NO;
    }
    else {
        self.text = nil;
        self.hidden = YES;
    }
}

#pragma mark Private

- (void)play_displayDurationLabelWithName:(NSString *)name bulletColor:(UIColor *)bulletColor
{
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"  %@  ", name].uppercaseString
                                                                                       attributes:@{ NSFontAttributeName : [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleCaption],
                                                                                                     NSForegroundColorAttributeName : UIColor.whiteColor }];
    
    if (bulletColor) {
        [attributedText appendAttributedString:[[NSAttributedString alloc] initWithString:PlaySRGNonLocalizedString(@"●  ")
                                                                               attributes:@{ NSFontAttributeName : [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleCaption],
                                                                                             NSForegroundColorAttributeName : bulletColor }]];
    }
    
    self.attributedText = attributedText.copy;
    self.hidden = NO;
}

@end
