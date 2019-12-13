//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "HomeRadioLiveTableViewCell.h"

#import "ApplicationConfiguration.h"
#import "ApplicationSettings.h"
#import "ChannelService.h"
#import "MediaPlayerViewController.h"
#import "NSBundle+PlaySRG.h"
#import "NSDateFormatter+PlaySRG.h"
#import "SmartTimer.h"
#import "SRGProgram+PlaySRG.h"
#import "UIColor+PlaySRG.h"
#import "UIImageView+PlaySRG.h"
#import "UILabel+PlaySRG.h"
#import "UIViewController+PlaySRG.h"

#import <libextobjc/libextobjc.h>
#import <SRGAppearance/SRGAppearance.h>

@interface HomeRadioLiveTableViewCell ()

@property (nonatomic) SRGMedia *media;
@property (nonatomic) SRGChannel *channel;

@property (nonatomic, readonly, getter=isDataAvailable) BOOL dataAvailable;

@property (nonatomic, weak) IBOutlet UIView *mainView;
@property (nonatomic, weak) IBOutlet UIView *placeholderView;

@property (nonatomic, weak) IBOutlet UIView *livestreamPlaceholderView;
@property (nonatomic, weak) IBOutlet UIView *livestreamButtonPlaceholderView;
@property (nonatomic, weak) IBOutlet UIImageView *placeholderImageView;

@property (nonatomic, weak) IBOutlet UIView *livestreamView;
@property (nonatomic, weak) IBOutlet UIButton *livestreamButton;
@property (nonatomic, weak) IBOutlet UIImageView *livestreamButtonImageView;

@property (nonatomic, weak) IBOutlet UIImageView *thumbnailImageView;
@property (nonatomic, weak) IBOutlet UILabel *liveLabel;

@property (nonatomic, weak) IBOutlet UIView *blockingOverlayView;
@property (nonatomic, weak) IBOutlet UIImageView *blockingReasonImageView;

@property (nonatomic, weak) IBOutlet UIView *mediaView;
@property (nonatomic) IBOutletCollection(UILabel) NSArray *nowLiveLabels;
@property (nonatomic, weak) IBOutlet UILabel *titleLabel;
@property (nonatomic, weak) IBOutlet UILabel *subtitleLabel;

@property (nonatomic, weak) IBOutlet UIProgressView *progressView;

@property (nonatomic) SmartTimer *updateTimer;

@end

@implementation HomeRadioLiveTableViewCell

#pragma mark Overrides

+ (CGFloat)heightForHomeSectionInfo:(HomeSectionInfo *)homeSectionInfo bounds:(CGRect)bounds featured:(BOOL)featured
{
    return [self isLivestreamButtonHiddenForHomeSectionInfo:homeSectionInfo] ? 106.f : 164.f;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    UIColor *backgroundColor = UIColor.play_blackColor;
    self.backgroundColor = backgroundColor;
    self.selectedBackgroundView.backgroundColor = backgroundColor;
    
    [self.nowLiveLabels enumerateObjectsUsingBlock:^(UILabel * _Nonnull label, NSUInteger idx, BOOL * _Nonnull stop) {
        label.backgroundColor = backgroundColor;
        label.textColor = UIColor.play_lightGrayColor;
    }];
    
    self.titleLabel.backgroundColor = backgroundColor;
    
    self.subtitleLabel.backgroundColor = backgroundColor;
    self.subtitleLabel.textColor = UIColor.play_lightGrayColor;
    
    self.mainView.hidden = YES;
    self.placeholderView.hidden = NO;
    
    self.progressView.progressTintColor = UIColor.play_progressRedColor;
    
    self.mediaView.accessibilityHint = PlaySRGAccessibilityLocalizedString(@"Plays livestream.", @"Livestream play action hint");
    
    self.livestreamButtonPlaceholderView.backgroundColor = UIColor.play_lightGrayButtonBackgroundColor;
    self.livestreamButtonPlaceholderView.layer.cornerRadius = 4.f;
    self.livestreamButtonPlaceholderView.layer.masksToBounds = YES;
    
    self.placeholderImageView.image = [UIImage play_vectorImageAtPath:FilePathForImagePlaceholder(ImagePlaceholderMedia)
                                                            withScale:ImageScaleSmall];
    
    self.livestreamButton.backgroundColor = UIColor.play_lightGrayButtonBackgroundColor;
    self.livestreamButton.layer.cornerRadius = 4.f;
    self.livestreamButton.layer.masksToBounds = YES;
    [self.livestreamButton setTitle:nil forState:UIControlStateNormal];
    
    self.livestreamButtonImageView.tintColor = UIColor.whiteColor;
    
    self.livestreamButton.accessibilityHint = PlaySRGAccessibilityLocalizedString(@"Select regional radio", @"Regional livestream selection hint");
    
    self.thumbnailImageView.backgroundColor = UIColor.play_grayThumbnailImageViewBackgroundColor;
    
    self.blockingOverlayView.hidden = YES;
    
    self.liveLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleCaption];
    self.liveLabel.backgroundColor = UIColor.play_blackDurationLabelBackgroundColor;
    [self.liveLabel play_displayDurationLabelForLive];
    
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openLiveRadio:)];
    [self.mediaView addGestureRecognizer:tapGestureRecognizer];
    
    [self reloadData];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    [self unregisterChannelUpdatesWithMedia:self.media];
    self.media = nil;
    self.channel = nil;
    
    self.blockingOverlayView.hidden = YES;
    
    [self.thumbnailImageView play_resetImage];
}

- (void)willMoveToWindow:(UIWindow *)newWindow
{
    [super willMoveToWindow:newWindow];
    
    if (newWindow) {
        [self registerForChannelUpdatesWithMedia:self.media];
        
        @weakify(self)
        self.updateTimer = [SmartTimer timerWithTimeInterval:1. repeats:YES background:NO queue:NULL block:^{
            @strongify(self)
            [self reloadData];
        }];
    }
    else {
        [self unregisterChannelUpdatesWithMedia:self.media];
        
        self.updateTimer = nil;       // Invalidate timer
    }
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    
    [self play_registerForPreview];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    
    [self play_registerForPreview];
}

#pragma mark Accessibility

- (BOOL)isAccessibilityElement
{
    return NO;
}

- (NSArray *)accessibilityElements
{
    return self.dataAvailable ? @[self.livestreamButton, self.mediaView] : nil;
}

#pragma mark Getters and setters

+ (BOOL)isLivestreamButtonHiddenForHomeSectionInfo:(HomeSectionInfo *)homeSectionInfo
{
    return homeSectionInfo.items.count < 2;
}

- (void)setHomeSectionInfo:(HomeSectionInfo *)homeSectionInfo featured:(BOOL)featured
{
    [self unregisterChannelUpdatesWithMedia:self.media];
    
    [super setHomeSectionInfo:homeSectionInfo featured:featured];
    
    if (homeSectionInfo && ! [self isEmpty]) {
        SRGMedia *media = ApplicationSettingSelectedLivestreamMediaForChannelUid(homeSectionInfo.identifier, homeSectionInfo.items);
        if (! media) {
            media = homeSectionInfo.items.firstObject;
        }
        self.media = media;
        
        [self registerForChannelUpdatesWithMedia:media];
        [self reloadData];
    }
    else {
        self.media = nil;
        [self reloadData];
    }
}

- (void)setMedia:(SRGMedia *)media
{
    [self unregisterChannelUpdatesWithMedia:_media];
    _media = media;
    [self registerForChannelUpdatesWithMedia:media];
}

- (void)setUpdateTimer:(SmartTimer *)updateTimer
{
    [_updateTimer invalidate];
    _updateTimer = updateTimer;
    [updateTimer resume];
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

- (BOOL)isDataAvailable
{
    return self.channel != nil;
}

- (void)reloadData
{
    BOOL islivestreamButtonHidden = [HomeRadioLiveTableViewCell isLivestreamButtonHiddenForHomeSectionInfo:self.homeSectionInfo];
    self.livestreamPlaceholderView.hidden = islivestreamButtonHidden;
    self.livestreamView.hidden = islivestreamButtonHidden;
    
    [self.nowLiveLabels enumerateObjectsUsingBlock:^(UILabel * _Nonnull label, NSUInteger idx, BOOL * _Nonnull stop) {
        label.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleTitle];
        label.text = NSLocalizedString(@"On air", @"Short introductory text for what is currently playing on the radio");
    }];
    
    // For livestreams, only rely on channel information
    if (! self.dataAvailable) {
        self.mediaView.isAccessibilityElement = NO;
        
        self.mainView.hidden = YES;
        self.placeholderView.hidden = NO;
        return;
    }
    
    self.mediaView.isAccessibilityElement = YES;
    
    self.mainView.hidden = NO;
    self.placeholderView.hidden = YES;
    
    self.livestreamButton.titleLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleBody];
    
    NSString *title = ([self.channel.uid isEqualToString:self.media.uid]) ? NSLocalizedString(@"Choose a regional radio", @"Title displayed on the regional radio selection button") : self.channel.title;
    
    // Avoid ugly animation when setting the title, see https://stackoverflow.com/a/22101732/760435
    [UIView performWithoutAnimation:^{
        [self.livestreamButton setTitle:title forState:UIControlStateNormal];
        [self.livestreamButton layoutIfNeeded];
    }];
    
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
    
    self.titleLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleBody];
    self.subtitleLabel.font = [UIFont srg_lightFontWithTextStyle:SRGAppearanceFontTextStyleSubtitle];
    
    NSString *accessibilityLabel = [NSString stringWithFormat:PlaySRGAccessibilityLocalizedString(@"%@ live", @"Live content label, with a channel title"), self.channel.title];
    
    SRGProgram *currentProgram = self.channel.currentProgram;
    if ([currentProgram play_containsDate:NSDate.date]) {
        self.titleLabel.text = currentProgram.title;
        self.subtitleLabel.text = [NSString stringWithFormat:@"%@ - %@", [NSDateFormatter.play_timeFormatter stringFromDate:currentProgram.startDate], [NSDateFormatter.play_timeFormatter stringFromDate:currentProgram.endDate]];
        
        accessibilityLabel = [accessibilityLabel stringByAppendingFormat:@", %@", currentProgram.title];
        
        float progress = [NSDate.date timeIntervalSinceDate:currentProgram.startDate] / ([currentProgram.endDate timeIntervalSinceDate:currentProgram.startDate]);
        self.progressView.progress = fmaxf(fminf(progress, 1.f), 0.f);
        self.progressView.hidden = NO;
        
        [self.thumbnailImageView play_requestImageForObject:currentProgram withScale:ImageScaleSmall type:SRGImageTypeDefault placeholder:ImagePlaceholderMedia unavailabilityHandler:^{
            [self.thumbnailImageView play_requestImageForObject:self.channel withScale:ImageScaleSmall type:SRGImageTypeDefault placeholder:ImagePlaceholderMedia];
        }];
    }
    else {
        self.titleLabel.text = self.channel.title;
        self.subtitleLabel.text = nil;
        self.progressView.hidden = YES;
        
        [self.thumbnailImageView play_requestImageForObject:self.channel withScale:ImageScaleSmall type:SRGImageTypeDefault placeholder:ImagePlaceholderMedia];
    }
    
    self.subtitleLabel.hidden = (self.subtitleLabel.text == nil);
    
    self.mediaView.accessibilityLabel = accessibilityLabel;
    
    [self.liveLabel play_displayDurationLabelForLive];
}

#pragma mark Previewing protocol

- (id)previewObject
{
    return self.media;
}

- (NSValue *)previewAnchorRect
{
    CGRect imageViewFrameInSelf = [self.thumbnailImageView convertRect:self.thumbnailImageView.bounds toView:self];
    return [NSValue valueWithCGRect:imageViewFrameInSelf];
}

#pragma mark Actions

- (IBAction)selectLivestreamMedia:(id)sender
{
    if ([HomeRadioLiveTableViewCell isLivestreamButtonHiddenForHomeSectionInfo:self.homeSectionInfo]) {
        return;
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Regional radios", @"Title of the action view to choose a regional radio")
                                                                             message:NSLocalizedString(@"Choose a regional radio", @"Information message of the action view to choose a regional radio")
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
    
    [self.homeSectionInfo.items enumerateObjectsUsingBlock:^(SRGMedia * _Nonnull media, NSUInteger idx, BOOL * _Nonnull stop) {
        [alertController addAction:[UIAlertAction actionWithTitle:media.title style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            ApplicationSettingSetSelectedLiveStreamURNForChannelUid(self.homeSectionInfo.identifier, media.URN);
            self.media = media;
            [self reloadData];
            
            SRGMedia *currentMedia = SRGLetterboxService.sharedService.controller.media;
            if (currentMedia) {
                if ([self.homeSectionInfo.items containsObject:currentMedia] && currentMedia != self.media) {
                    SRGMediaPlayerPlaybackState currentPlaybackState = SRGLetterboxService.sharedService.controller.playbackState;
                    if (currentPlaybackState == SRGMediaPlayerPlaybackStatePlaying) {
                        [SRGLetterboxService.sharedService.controller playMedia:self.media atPosition:nil withPreferredSettings:ApplicationSettingPlaybackSettings()];
                    }
                    else {
                        [SRGLetterboxService.sharedService.controller prepareToPlayMedia:self.media atPosition:nil withPreferredSettings:ApplicationSettingPlaybackSettings() completionHandler:nil];
                    }
                }
            }
            else {
                NSString *lastPlayedRadioLiveUid = [NSUserDefaults.standardUserDefaults stringForKey:PlaySRGSettingLastPlayedRadioLiveURN];
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGMedia.new, uid), lastPlayedRadioLiveUid];
                SRGMedia *lastPlayedMedia = [self.homeSectionInfo.items filteredArrayUsingPredicate:predicate].firstObject;
                if (! lastPlayedRadioLiveUid || (lastPlayedMedia && ! [lastPlayedMedia.uid isEqualToString:self.media.uid])) {
                    SRGLetterboxController *serviceController = SRGLetterboxService.sharedService.controller;
                    if (serviceController) {
                        [serviceController prepareToPlayMedia:self.media atPosition:nil withPreferredSettings:ApplicationSettingPlaybackSettings() completionHandler:nil];
                    }
                    else {
                        SRGLetterboxController *letterboxController = [[SRGLetterboxController alloc] init];
                        ApplicationConfigurationApplyControllerSettings(letterboxController);
                        [letterboxController prepareToPlayMedia:self.media atPosition:nil withPreferredSettings:ApplicationSettingPlaybackSettings() completionHandler:nil];
                        [SRGLetterboxService.sharedService enableWithController:letterboxController pictureInPictureDelegate:nil];
                    }
                }
            }
        }]];
    }];
    
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Title of a cancel button") style:UIAlertActionStyleCancel handler:nil]];
    
    UIPopoverPresentationController *popoverPresentationController = alertController.popoverPresentationController;
    popoverPresentationController.sourceView = self.livestreamButtonImageView;
    popoverPresentationController.sourceRect = self.livestreamButtonImageView.bounds;
    popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    
    [UIApplication.sharedApplication.keyWindow.rootViewController presentViewController:alertController animated:YES completion:nil];
}

- (IBAction)openLiveRadio:(id)sender
{
    if (self.media) {
        [self.nearestViewController play_presentMediaPlayerWithMedia:self.media position:nil airPlaySuggestions:YES fromPushNotification:NO animated:YES completion:nil];
    }
}

@end
