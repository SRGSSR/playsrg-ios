//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "HomeMediaCollectionViewCell.h"

#import "AnalyticsConstants.h"
#import "ApplicationConfiguration.h"
#import "ApplicationSettings.h"
#import "Download.h"
#import "History.h"
#import "NSBundle+PlaySRG.h"
#import "NSDateFormatter+PlaySRG.h"
#import "NSString+PlaySRG.h"
#import "PlayDurationFormatter.h"
#import "SRGMedia+PlaySRG.h"
#import "UIColor+PlaySRG.h"
#import "UIImageView+PlaySRG.h"
#import "UILabel+PlaySRG.h"

#import <SRGAnalytics/SRGAnalytics.h>
#import <SRGAppearance/SRGAppearance.h>
#import <SRGUserData/SRGUserData.h>

@interface HomeMediaCollectionViewCell ()

@property (nonatomic) SRGMedia *media;
@property (nonatomic) SRGModule *module;
@property (nonatomic, getter=isFeatured) BOOL featured;

@property (nonatomic, weak) IBOutlet UIView *mediaView;
@property (nonatomic, weak) IBOutlet UIView *placeholderView;
@property (nonatomic, weak) IBOutlet UIImageView *placeholderImageView;

@property (nonatomic, weak) IBOutlet UILabel *editorialLabel;
@property (nonatomic, weak) IBOutlet UILabel *titleLabel;
@property (nonatomic, weak) IBOutlet UILabel *subtitleLabel;
@property (nonatomic, weak) IBOutlet UIImageView *thumbnailImageView;
@property (nonatomic, weak) IBOutlet UILabel *durationLabel;
@property (nonatomic, weak) IBOutlet UIImageView *youthProtectionColorImageView;
@property (nonatomic, weak) IBOutlet UIImageView *downloadStatusImageView;
@property (nonatomic, weak) IBOutlet UIImageView *media360ImageView;
@property (nonatomic, weak) IBOutlet UILabel *webFirstLabel;
@property (nonatomic, weak) IBOutlet UILabel *subtitlesLabel;
@property (nonatomic, weak) IBOutlet UIImageView *audioDescriptionImageView;

@property (nonatomic, weak) IBOutlet UIView *blockingOverlayView;
@property (nonatomic, weak) IBOutlet UIImageView *blockingReasonImageView;

@property (nonatomic, weak) IBOutlet UIProgressView *progressView;

@property (nonatomic) IBOutletCollection(NSLayoutConstraint) NSArray *titleVerticalSpacingConstraints;

@property (nonatomic, copy) NSString *progressTaskHandle;

@end

@implementation HomeMediaCollectionViewCell

#pragma mark Overrides

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.backgroundColor = UIColor.play_blackColor;
    
    self.mediaView.hidden = YES;
    self.placeholderView.hidden = NO;
    
    // Accommodate all kinds of usages (medium or small)
    self.placeholderImageView.image = [UIImage play_vectorImageAtPath:FilePathForImagePlaceholder(ImagePlaceholderMedia)
                                                            withScale:ImageScaleMedium];
    
    self.subtitleLabel.textColor = UIColor.play_lightGrayColor;
    
    self.thumbnailImageView.backgroundColor = UIColor.play_grayThumbnailImageViewBackgroundColor;
    
    self.editorialLabel.backgroundColor = UIColor.play_redColor;
    self.editorialLabel.text = [NSString stringWithFormat:@"  %@  ", NSLocalizedString(@"OUR PICK", @"Label on the editor or trending lists in the home page, for prefered contents. Known as the SRF-TIPP label. Display in uppercase.").uppercaseString];
    self.editorialLabel.hidden = YES;
    
    self.durationLabel.backgroundColor = UIColor.play_blackDurationLabelBackgroundColor;
    
    [self.webFirstLabel play_setWebFirstBadge];
    [self.subtitlesLabel play_setSubtitlesAvailableBadge];
    self.audioDescriptionImageView.tintColor = UIColor.play_whiteBadgeColor;
    
    self.youthProtectionColorImageView.hidden = YES;
    self.webFirstLabel.hidden = YES;
    self.subtitlesLabel.hidden = YES;
    self.audioDescriptionImageView.hidden = YES;

    self.progressView.progressTintColor = UIColor.play_progressRedColor;
    
    self.downloadStatusImageView.tintColor = UIColor.play_lightGrayColor;
    
    self.blockingOverlayView.hidden = YES;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    self.media = nil;
    self.module = nil;
    
    self.featured = NO;
    
    self.mediaView.hidden = YES;
    self.placeholderView.hidden = NO;
    
    self.youthProtectionColorImageView.hidden = YES;
    self.webFirstLabel.hidden = YES;
    self.subtitlesLabel.hidden = YES;
    self.audioDescriptionImageView.hidden = YES;
    
    self.blockingOverlayView.hidden = YES;
    
    self.progressView.hidden = YES;
    
    [self.thumbnailImageView play_resetImage];
    
    self.backgroundColor = UIColor.play_blackColor;
}

- (void)willMoveToWindow:(UIWindow *)newWindow
{
    [super willMoveToWindow:newWindow];
    
    if (newWindow) {
        // Ensure proper state when the view is reinserted
        [self updateDownloadStatus];
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(downloadStateDidChange:)
                                                   name:DownloadStateDidChangeNotification
                                                 object:nil];
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(historyEntriesDidChange:)
                                                   name:SRGHistoryEntriesDidChangeNotification
                                                 object:SRGUserData.currentUserData.history];
    }
    else {
        [NSNotificationCenter.defaultCenter removeObserver:self name:DownloadStateDidChangeNotification object:nil];
        [NSNotificationCenter.defaultCenter removeObserver:self name:SRGHistoryEntriesDidChangeNotification object:SRGUserData.currentUserData.history];
    }
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    
    [self play_registerForPreview];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    for (NSLayoutConstraint *layoutConstraint in self.titleVerticalSpacingConstraints) {
        layoutConstraint.constant = self.featured ? 8.f : 5.f;
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    
    [self play_registerForPreview];
}

#pragma mark Accessibility

- (BOOL)isAccessibilityElement
{
    return self.media != nil;
}

- (NSString *)accessibilityLabel
{
    NSMutableString *accessibilityLabel = self.media.title.mutableCopy;
    
    if (self.media.show.title && ! [self.media.title containsString:self.media.show.title]) {
        [accessibilityLabel appendFormat:@", %@", self.media.show.title];
    }
    
    NSString *youthProtectionAccessibilityLabel = SRGAccessibilityLabelForYouthProtectionColor(self.media.youthProtectionColor);
    if (self.youthProtectionColorImageView.image && youthProtectionAccessibilityLabel) {
        [accessibilityLabel appendFormat:@". %@", youthProtectionAccessibilityLabel];
    }
    
    BOOL downloaded = [Download downloadForMedia:self.media].state == DownloadStateDownloaded;
    if (self.media.play_audioDescriptionAvailable && ! downloaded) {
        [accessibilityLabel appendFormat:@". %@", PlaySRGAccessibilityLocalizedString(@"Audio described", @"Accessibility label for a media cell with audio description")];
    }
    
    return accessibilityLabel.copy;
}

- (NSString *)accessibilityHint
{
    return PlaySRGAccessibilityLocalizedString(@"Plays the content.", @"Media cell hint");
}

#pragma mark Data

- (void)setMedia:(SRGMedia *)media module:(SRGModule *)module featured:(BOOL)featured
{
    self.media = media;
    self.module = module;
    self.featured = featured;
    
    [self reloadData];
    
    [self updateDownloadStatus];
    [self updateHistoryStatus];
}

#pragma mark UI

- (void)reloadData
{
    UIColor *backgroundColor = UIColor.play_blackColor;
    if (self.module && ! ApplicationConfiguration.sharedApplicationConfiguration.moduleColorsDisabled) {
        backgroundColor = self.module.backgroundColor;
    }
    self.backgroundColor = backgroundColor;
    
    if (! self.media) {
        self.mediaView.hidden = YES;
        self.placeholderView.hidden = NO;
        return;
    }
    
    self.mediaView.hidden = NO;
    self.placeholderView.hidden = YES;
    
    self.titleLabel.font = [UIFont srg_mediumFontWithTextStyle:self.featured ? SRGAppearanceFontTextStyleTitle : SRGAppearanceFontTextStyleBody];
    self.titleLabel.backgroundColor = backgroundColor;
    self.titleLabel.text = self.media.title;
    
    self.durationLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleCaption];
    self.editorialLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleCaption];
    
    self.editorialLabel.hidden = (self.media.source != SRGSourceEditor);
    
    SRGAppearanceFontTextStyle subtitleTextStyle = self.featured ? SRGAppearanceFontTextStyleBody : SRGAppearanceFontTextStyleSubtitle;
    ImageScale imageScale = self.featured ? ImageScaleMedium : ImageScaleSmall;
    
    if (self.media.contentType != SRGContentTypeLivestream) {
        NSString *showTitle = self.media.show.title;
        if (showTitle && ! [self.media.title containsString:showTitle]) {
            NSMutableAttributedString *subtitle = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ - ", showTitle]
                                                                                         attributes:@{ NSFontAttributeName : [UIFont srg_mediumFontWithTextStyle:subtitleTextStyle] }];
            
            BOOL displayTime = ([self.media blockingReasonAtDate:NSDate.date] == SRGBlockingReasonStartDate) && self.media.play_today;
            NSDateFormatter *dateFormatter = self.featured ? NSDateFormatter.play_relativeDateAndTimeFormatter : (displayTime ? NSDateFormatter.play_shortTimeFormatter : NSDateFormatter.play_relativeDateFormatter);
            [subtitle appendAttributedString:[[NSAttributedString alloc] initWithString:[dateFormatter stringFromDate:self.media.date].play_localizedUppercaseFirstLetterString
                                                                             attributes:@{ NSFontAttributeName : [UIFont srg_lightFontWithTextStyle:subtitleTextStyle] }]];
            
            self.subtitleLabel.attributedText = subtitle.copy;
        }
        else {
            self.subtitleLabel.font = [UIFont srg_lightFontWithTextStyle:subtitleTextStyle];
            self.subtitleLabel.text = [NSDateFormatter.play_relativeDateAndTimeFormatter stringFromDate:self.media.date].play_localizedUppercaseFirstLetterString;
        }
    }
    else {
        self.subtitleLabel.text = nil;
    }
    self.subtitleLabel.backgroundColor = backgroundColor;
    
    [self.durationLabel play_displayDurationLabelForMediaMetadata:self.media];
    
    self.media360ImageView.hidden = (self.media.presentation != SRGPresentation360);
    
    BOOL downloaded = [Download downloadForMedia:self.media].state == DownloadStateDownloaded;
    self.webFirstLabel.hidden = ! self.media.play_webFirst;
    self.subtitlesLabel.hidden = (! ApplicationSettingSubtitleAvailabilityDisplayed() || ! self.media.play_subtitlesAvailable || downloaded);
    self.audioDescriptionImageView.hidden = (! ApplicationSettingAudioDescriptionAvailabilityDisplayed() || ! self.media.play_audioDescriptionAvailable || downloaded);

    self.youthProtectionColorImageView.image = YouthProtectionImageForColor(self.media.youthProtectionColor);
    self.youthProtectionColorImageView.hidden = (self.youthProtectionColorImageView.image == nil);
    
    UIColor *titleTextColor = UIColor.whiteColor;
    UIColor *subtitleTextColor = UIColor.play_lightGrayColor;
    if (self.module && ! ApplicationConfiguration.sharedApplicationConfiguration.moduleColorsDisabled) {
        titleTextColor = self.module.linkColor ?: ApplicationConfiguration.sharedApplicationConfiguration.moduleDefaultLinkColor;
        subtitleTextColor = self.module.textColor ?: ApplicationConfiguration.sharedApplicationConfiguration.moduleDefaultTextColor;
    }
    
    SRGBlockingReason blockingReason = [self.media blockingReasonAtDate:NSDate.date];
    if (blockingReason == SRGBlockingReasonNone || blockingReason == SRGBlockingReasonStartDate) {
        self.blockingOverlayView.hidden = YES;
        
        self.titleLabel.textColor = titleTextColor;
    }
    else {
        self.blockingOverlayView.hidden = NO;
        self.blockingReasonImageView.image = [UIImage play_imageForBlockingReason:blockingReason];
        
        self.titleLabel.textColor = subtitleTextColor;
    }
    self.subtitleLabel.textColor = subtitleTextColor;
    
    id<SRGImage> imageObject = (self.media.contentType == SRGContentTypeLivestream && self.media.channel) ? self.media.channel : self.media;
    [self.thumbnailImageView play_requestImageForObject:imageObject withScale:imageScale type:SRGImageTypeDefault placeholder:ImagePlaceholderMedia];
}

- (void)updateDownloadStatus
{
    Download *download = [Download downloadForMedia:self.media];
    if (!download) {
        BOOL downloadsHintsHidden = ApplicationConfiguration.sharedApplicationConfiguration.downloadsHintsHidden;
        
        [self.downloadStatusImageView play_stopAnimating];
        self.downloadStatusImageView.image = [UIImage imageNamed:@"downloadable-16"];
        
        self.downloadStatusImageView.hidden = downloadsHintsHidden ? YES : ! [Download canDownloadMedia:self.media];
        return;
    }
    
    self.downloadStatusImageView.hidden = NO;
    
    UIColor *imageColor = UIColor.play_lightGrayColor;
    if (self.module && ! ApplicationConfiguration.sharedApplicationConfiguration.moduleColorsDisabled) {
        imageColor = self.module.linkColor ?: ApplicationConfiguration.sharedApplicationConfiguration.moduleDefaultTextColor;
    }
    
    UIImage *downloadImage = nil;
    
    switch (download.state) {
        case DownloadStateAdded:
        case DownloadStateDownloadingSuspended: {
            [self.downloadStatusImageView play_stopAnimating];
            downloadImage = [UIImage imageNamed:@"downloadable_stop-16"];
            break;
        }
            
        case DownloadStateDownloading: {
            [self.downloadStatusImageView play_startAnimatingDownloading16WithTintColor:imageColor];
            downloadImage = self.downloadStatusImageView.image;
            break;
        }
            
        case DownloadStateDownloaded: {
            [self.downloadStatusImageView play_stopAnimating];
            downloadImage = [UIImage imageNamed:@"downloadable_full-16"];
            break;
        }
            
        case DownloadStateDownloadable:
        case DownloadStateRemoved: {
            [self.downloadStatusImageView play_stopAnimating];
            downloadImage = [UIImage imageNamed:@"downloadable-16"];
            break;
        }
            
        default: {
            [self.downloadStatusImageView play_stopAnimating];
            break;
        }
    }
    
    self.downloadStatusImageView.image = downloadImage;
    self.downloadStatusImageView.tintColor = imageColor;
}

- (void)updateHistoryStatus
{
    HistoryPlaybackProgressAsyncCancel(self.progressTaskHandle);
    self.progressTaskHandle = HistoryPlaybackProgressForMediaMetadataAsync(self.media, ^(float progress) {
        self.progressView.hidden = (progress == 0.f);
        self.progressView.progress = progress;
    });
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

#pragma mark Notifications

- (void)downloadStateDidChange:(NSNotification *)notification
{
    [self updateDownloadStatus];
}

- (void)historyEntriesDidChange:(NSNotification *)notification
{
    NSArray<NSString *> *updatedURNs = notification.userInfo[SRGHistoryEntriesUidsKey];
    if (self.media && [updatedURNs containsObject:self.media.URN]) {
        [self updateHistoryStatus];
    }
}

@end
