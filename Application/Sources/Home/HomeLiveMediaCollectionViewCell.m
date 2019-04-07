//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "HomeLiveMediaCollectionViewCell.h"

#import "AnalyticsConstants.h"
#import "ChannelService.h"
#import "NSBundle+PlaySRG.h"
#import "NSDateFormatter+PlaySRG.h"
#import "NSTimer+PlaySRG.h"
#import "PlayDateComponentsFormatter.h"
#import "SRGChannel+PlaySRG.h"
#import "SRGMedia+PlaySRG.h"
#import "SRGProgram+PlaySRG.h"
#import "UIColor+PlaySRG.h"
#import "UIImageView+PlaySRG.h"
#import "UILabel+PlaySRG.h"

#import <CoconutKit/CoconutKit.h>
#import <libextobjc/libextobjc.h>
#import <SRGAnalytics/SRGAnalytics.h>
#import <SRGAppearance/SRGAppearance.h>

@interface HomeLiveMediaCollectionViewCell ()

@property (nonatomic) SRGMedia *media;
@property (nonatomic, getter=isFeatured) BOOL featured;
@property (nonatomic) SRGChannel *channel;

@property (nonatomic, weak) IBOutlet UIView *mediaView;
@property (nonatomic, weak) IBOutlet UIView *placeholderView;
@property (nonatomic, weak) IBOutlet UIImageView *placeholderImageView;

@property (nonatomic, weak) IBOutlet UIImageView *logoImageView;
@property (nonatomic, weak) IBOutlet UILabel *titleLabel;
@property (nonatomic, weak) IBOutlet UILabel *subtitleLabel;
@property (nonatomic, weak) IBOutlet UIImageView *thumbnailImageView;
@property (nonatomic, weak) IBOutlet UILabel *durationLabel;

@property (nonatomic, weak) IBOutlet UIView *blockingOverlayView;
@property (nonatomic, weak) IBOutlet UIImageView *blockingReasonImageView;

@property (nonatomic, weak) IBOutlet UIProgressView *progressView;

@property (nonatomic) NSTimer *updateTimer;

@end

@implementation HomeLiveMediaCollectionViewCell

#pragma mark Getters and setters

- (void)setUpdateTimer:(NSTimer *)updateTimer
{
    [_updateTimer invalidate];
    _updateTimer = updateTimer;
}

#pragma mark Overrides

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.backgroundColor = UIColor.clearColor;
    
    self.mediaView.alpha = 0.f;
    self.placeholderView.alpha = 1.f;
    
    self.progressView.progressTintColor = UIColor.play_progressRedColor;
    
    // Accommodate all kinds of usages (medium or small)
    self.placeholderImageView.image = [UIImage play_vectorImageAtPath:FilePathForImagePlaceholder(ImagePlaceholderMedia)
                                                            withScale:ImageScaleMedium];
    
    self.subtitleLabel.textColor = UIColor.play_lightGrayColor;
    
    self.thumbnailImageView.backgroundColor = UIColor.play_grayThumbnailImageViewBackgroundColor;
    
    self.durationLabel.backgroundColor = UIColor.play_blackDurationLabelBackgroundColor;
    
    self.blockingOverlayView.hidden = YES;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    [self unregisterChannelUpdatesWithMedia:self.media];
    self.media = nil;
    
    self.featured = NO;
    self.channel = nil;
    
    self.mediaView.alpha = 0.f;
    self.placeholderView.alpha = 1.f;
    self.progressView.progress = 1.f;
    
    self.blockingOverlayView.hidden = YES;
    
    [self.thumbnailImageView play_resetImage];
}

- (void)willMoveToWindow:(UIWindow *)newWindow
{
    [super willMoveToWindow:newWindow];
    
    if (newWindow) {
        // Ensure proper state when the view is reinserted
        [self registerForChannelUpdatesWithMedia:self.media];
        
        @weakify(self)
        self.updateTimer = [NSTimer play_timerWithTimeInterval:1. repeats:YES block:^(NSTimer * _Nonnull timer) {
            @strongify(self)
            [self reloadData];
        }];
    }
    else {
        [self unregisterChannelUpdatesWithMedia:self.media];
        
        self.updateTimer = nil;       // Invalidate timer
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    
    [self.nearestViewController registerForPreviewingWithDelegate:self.nearestViewController sourceView:self];
}

#pragma mark Accessibility

- (BOOL)isAccessibilityElement
{
    return self.channel != nil;
}

- (NSString *)accessibilityLabel
{
    if (self.media.contentType == SRGContentTypeLivestream) {
        NSMutableString *accessibilityLabel = [NSMutableString stringWithFormat:PlaySRGAccessibilityLocalizedString(@"%@ live", @"Live content label, with a channel title"), self.channel.title];
        if (self.channel.currentProgram) {
            [accessibilityLabel appendFormat:@", %@", self.channel.currentProgram.title];
        }
        return [accessibilityLabel copy];
    }
    else {
        NSMutableString *accessibilityLabel = [self.media.title mutableCopy];
        if (self.media.show.title && ! [self.media.title containsString:self.media.show.title]) {
            [accessibilityLabel appendFormat:@", %@", self.media.show.title];
        }
        return [accessibilityLabel copy];
    }
}

- (NSString *)accessibilityHint
{
    return PlaySRGAccessibilityLocalizedString(@"Plays the content.", @"Media cell hint");
}

#pragma mark Data

- (void)setMedia:(SRGMedia *)media featured:(BOOL)featured
{
    [self unregisterChannelUpdatesWithMedia:self.media];
    
    self.media = media;
    self.featured = featured;
    self.channel = media.channel;
    
    [self registerForChannelUpdatesWithMedia:media];
    [self reloadData];
}

#pragma mark Channel updates

- (void)registerForChannelUpdatesWithMedia:(SRGMedia *)media
{
    if (! media) {
        return;
    }
    
    [ChannelService.sharedService registerObserver:self forChannelUpdatesWithMedia:media block:^(SRGChannel * _Nullable channel) {
        self.channel = channel ?: media.channel;
        [self reloadData];
    }];
}

- (void)unregisterChannelUpdatesWithMedia:(SRGMedia *)media
{
    if (! media) {
        return;
    }
    
    [ChannelService.sharedService unregisterObserver:self forMedia:media];
}

#pragma mark UI

- (void)reloadData
{
    if (! self.channel) {
        self.mediaView.alpha = 0.f;
        self.placeholderView.alpha = 1.f;
        return;
    }
    
    self.mediaView.alpha = 1.f;
    self.placeholderView.alpha = 0.f;
    
    self.logoImageView.image = self.channel.play_banner22Image;
    
    self.titleLabel.font = [UIFont srg_mediumFontWithTextStyle:self.featured ? SRGAppearanceFontTextStyleTitle : SRGAppearanceFontTextStyleBody];
    self.durationLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleCaption];
    
    SRGBlockingReason blockingReason = [self.media blockingReasonAtDate:NSDate.date];
    if (blockingReason == SRGBlockingReasonNone || blockingReason == SRGBlockingReasonStartDate) {
        self.blockingOverlayView.hidden = YES;
        
        self.titleLabel.textColor = UIColor.whiteColor;
    }
    else {
        self.blockingOverlayView.hidden = NO;
        self.blockingReasonImageView.image = [UIImage play_imageForBlockingReason:blockingReason];
        
        self.titleLabel.textColor = UIColor.play_lightGrayColor;
    }
    
    SRGAppearanceFontTextStyle subtitleTextStyle = self.featured ? SRGAppearanceFontTextStyleBody : SRGAppearanceFontTextStyleSubtitle;
    ImageScale imageScale = self.featured ? ImageScaleMedium : ImageScaleSmall;
    
    self.subtitleLabel.font = [UIFont srg_lightFontWithTextStyle:subtitleTextStyle];
    
    SRGProgram *currentProgram = self.channel.currentProgram;
    if ([currentProgram play_containsDate:NSDate.date]) {
        self.titleLabel.text = currentProgram.title;
        self.subtitleLabel.text = [NSString stringWithFormat:@"%@ - %@", [NSDateFormatter.play_timeFormatter stringFromDate:currentProgram.startDate], [NSDateFormatter.play_timeFormatter stringFromDate:currentProgram.endDate]];
        
        float progress = [NSDate.date timeIntervalSinceDate:currentProgram.startDate] / ([currentProgram.endDate timeIntervalSinceDate:currentProgram.startDate]);
        self.progressView.progress = fmaxf(fminf(progress, 1.f), 0.f);
        
        [self.thumbnailImageView play_requestImageForObject:currentProgram withScale:imageScale type:SRGImageTypeDefault placeholder:ImagePlaceholderMedia unavailabilityHandler:^{
            [self.thumbnailImageView play_requestImageForObject:self.channel withScale:imageScale type:SRGImageTypeDefault placeholder:ImagePlaceholderMedia];
        }];
    }
    else {
        self.titleLabel.text = self.channel.title;
        self.subtitleLabel.text = NSLocalizedString(@"Currently", @"Text displayed on live cells when no program time information is available");
        self.progressView.progress = 1.f;
        
        [self.thumbnailImageView play_requestImageForObject:self.channel withScale:imageScale type:SRGImageTypeDefault placeholder:ImagePlaceholderMedia];
    }
    
    [self.durationLabel play_displayDurationLabelForMediaMetadata:self.media];
}

#pragma mark Previewing protocol

- (id)previewObject
{
    return self.media;
}

@end
