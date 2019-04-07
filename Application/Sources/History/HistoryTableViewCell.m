//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "HistoryTableViewCell.h"

#import "AnalyticsConstants.h"
#import "ApplicationConfiguration.h"
#import "Download.h"
#import "History.h"
#import "NSBundle+PlaySRG.h"
#import "NSDateFormatter+PlaySRG.h"
#import "NSString+PlaySRG.h"
#import "UIColor+PlaySRG.h"
#import "UIImage+PlaySRG.h"
#import "UIImageView+PlaySRG.h"
#import "UILabel+PlaySRG.h"

#import <CoconutKit/CoconutKit.h>
#import <libextobjc/libextobjc.h>
#import <SRGAnalytics/SRGAnalytics.h>
#import <SRGAppearance/SRGAppearance.h>
#import <SRGUserData/SRGUserData.h>

@interface HistoryTableViewCell ()

@property (nonatomic, weak) IBOutlet UILabel *titleLabel;
@property (nonatomic, weak) IBOutlet UILabel *subtitleLabel;
@property (nonatomic, weak) IBOutlet UIImageView *thumbnailImageView;
@property (nonatomic, weak) IBOutlet UILabel *durationLabel;
@property (nonatomic, weak) IBOutlet UIImageView *youthProtectionColorImageView;
@property (nonatomic, weak) IBOutlet UIImageView *downloadStatusImageView;
@property (nonatomic, weak) IBOutlet UIImageView *media360ImageView;

@property (nonatomic, weak) IBOutlet UIView *blockingOverlayView;
@property (nonatomic, weak) IBOutlet UIImageView *blockingReasonImageView;

@property (nonatomic, weak) IBOutlet UIProgressView *progressView;

@property (nonatomic) UIColor *blockingOverlayViewColor;
@property (nonatomic) UIColor *durationLabelBackgroundColor;

@end

@implementation HistoryTableViewCell

#pragma mark Overrides

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.backgroundColor = UIColor.play_blackColor;
    
    UIView *colorView = [[UIView alloc] init];
    colorView.backgroundColor = UIColor.play_blackColor;
    self.selectedBackgroundView = colorView;
    
    self.thumbnailImageView.backgroundColor = UIColor.play_grayThumbnailImageViewBackgroundColor;
    
    self.subtitleLabel.textColor = UIColor.play_lightGrayColor;
    
    self.durationLabel.backgroundColor = UIColor.play_blackDurationLabelBackgroundColor;
    
    self.youthProtectionColorImageView.hidden = YES;
    
    self.blockingOverlayViewColor = self.blockingOverlayView.backgroundColor;
    self.durationLabelBackgroundColor = self.durationLabel.backgroundColor;
    
    self.media360ImageView.layer.shadowOpacity = 0.3f;
    self.media360ImageView.layer.shadowRadius = 2.f;
    self.media360ImageView.layer.shadowOffset = CGSizeMake(0.f, 1.f);
    
    self.progressView.progressTintColor = UIColor.play_progressRedColor;
    
    self.downloadStatusImageView.tintColor = UIColor.play_lightGrayColor;
    
    @weakify(self)
    MGSwipeButton *deleteButton = [MGSwipeButton buttonWithTitle:@"" icon:[UIImage imageNamed:@"delete-22"] backgroundColor:UIColor.redColor callback:^BOOL(MGSwipeTableCell * _Nonnull cell) {
        @strongify(self)
        [self.cellDelegate historyTableViewCell:self deleteHistoryEntryForMedia:self.media];
        return YES;
    }];
    deleteButton.tintColor = UIColor.whiteColor;
    deleteButton.buttonWidth = 60.f;
    self.rightButtons = @[deleteButton];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    self.youthProtectionColorImageView.hidden = YES;
    
    self.blockingOverlayView.hidden = YES;
    self.progressView.hidden = YES;
    
    [self.thumbnailImageView play_resetImage];
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
                                               selector:@selector(historyDidChange:)
                                                   name:SRGHistoryDidChangeNotification
                                                 object:SRGUserData.currentUserData.history];
    }
    else {
        [NSNotificationCenter.defaultCenter removeObserver:self name:DownloadStateDidChangeNotification object:nil];
        [NSNotificationCenter.defaultCenter removeObserver:self name:SRGHistoryDidChangeNotification object:SRGUserData.currentUserData.history];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    
    [self.nearestViewController registerForPreviewingWithDelegate:self.nearestViewController sourceView:self];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    
    self.selectionStyle = editing ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    if (editing && self.swipeState != MGSwipeStateNone) {
        [self hideSwipeAnimated:animated];
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    if (self.editing) {
        [self updateDownloadStatus];
        self.blockingOverlayView.backgroundColor = self.blockingOverlayViewColor;
        self.durationLabel.backgroundColor = self.durationLabelBackgroundColor;
    }
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    
    if (self.editing) {
        [self updateDownloadStatus];
        self.blockingOverlayView.backgroundColor = self.blockingOverlayViewColor;
        self.durationLabel.backgroundColor = self.durationLabelBackgroundColor;
    }
}

#pragma mark Accessibility

- (NSString *)accessibilityLabel
{
    if (self.media.contentType == SRGContentTypeLivestream) {
        NSMutableString *accessibilityLabel = [NSMutableString stringWithFormat:PlaySRGAccessibilityLocalizedString(@"%@ live", @"Live content label, with a media title"), self.media.title];
        if (self.media.channel) {
            [accessibilityLabel appendFormat:@", %@", self.media.channel.title];
        }
        return [accessibilityLabel copy];
    }
    else {
        NSMutableString *accessibilityLabel = [self.media.title mutableCopy];
        
        if (self.media.show.title && ! [self.media.title containsString:self.media.show.title]) {
            [accessibilityLabel appendFormat:@", %@", self.media.show.title];
        }
        
        NSString *youthProtectionAccessibilityLabel = SRGAccessibilityLabelForYouthProtectionColor(self.media.youthProtectionColor);
        if (self.youthProtectionColorImageView.image && youthProtectionAccessibilityLabel) {
            [accessibilityLabel appendFormat:@". %@", youthProtectionAccessibilityLabel];
        }
        
        return [accessibilityLabel copy];
    }
}

- (NSString *)accessibilityHint
{
    return PlaySRGAccessibilityLocalizedString(@"Plays the content.", @"Media cell hint");
}

#pragma mark Getters and setters

- (void)setMedia:(SRGMedia *)media
{
    _media = media;
    
    self.titleLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleBody];
    self.titleLabel.text = media.title;
    
    if (media.contentType != SRGContentTypeLivestream) {
        NSString *showTitle = media.show.title;
        if (showTitle && ! [media.title containsString:showTitle]) {
            NSMutableAttributedString *subtitle = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ - ", showTitle]
                                                                                         attributes:@{ NSFontAttributeName : [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleSubtitle] }];
            [subtitle appendAttributedString:[[NSAttributedString alloc] initWithString:[NSDateFormatter.play_relativeDateFormatter stringFromDate:media.date].play_localizedUppercaseFirstLetterString
                                                                             attributes:@{ NSFontAttributeName : [UIFont srg_lightFontWithTextStyle:SRGAppearanceFontTextStyleSubtitle] }]];
            self.subtitleLabel.attributedText = [subtitle copy];
        }
        else {
            self.subtitleLabel.font = [UIFont srg_lightFontWithTextStyle:SRGAppearanceFontTextStyleSubtitle];
            self.subtitleLabel.text = [NSDateFormatter.play_relativeDateAndTimeFormatter stringFromDate:media.date].play_localizedUppercaseFirstLetterString;
        }
    }
    else {
        self.subtitleLabel.text = nil;
    }
    
    [self.durationLabel play_displayDurationLabelForMediaMetadata:media];
    
    self.media360ImageView.hidden = (media.presentation != SRGPresentation360);
    
    self.youthProtectionColorImageView.image = YouthProtectionImageForColor(self.media.youthProtectionColor);
    self.youthProtectionColorImageView.hidden = (self.youthProtectionColorImageView.image == nil);
    
    SRGBlockingReason blockingReason = [media blockingReasonAtDate:NSDate.date];
    if (blockingReason == SRGBlockingReasonNone || blockingReason == SRGBlockingReasonStartDate) {
        self.blockingOverlayView.hidden = YES;
        
        self.titleLabel.textColor = UIColor.whiteColor;
    }
    else {
        self.blockingOverlayView.hidden = NO;
        self.blockingReasonImageView.image = [UIImage play_imageForBlockingReason:blockingReason];
        
        self.titleLabel.textColor = UIColor.play_lightGrayColor;
    }
    
    id<SRGImage> imageObject = (media.contentType == SRGContentTypeLivestream && media.channel) ? media.channel : media;
    [self.thumbnailImageView play_requestImageForObject:imageObject withScale:ImageScaleSmall type:SRGImageTypeDefault placeholder:ImagePlaceholderMedia];
    
    [self updateDownloadStatus];
    [self updateHistoryStatus];
}

#pragma mark UI

- (void)updateDownloadStatus
{
    Download *download = [Download downloadForMedia:self.media];
    if (!download) {
        BOOL downloadsHintsHidden = ApplicationConfiguration.sharedApplicationConfiguration.downloadsHintsHidden;
        
        [self.downloadStatusImageView play_stopAnimating];
        self.downloadStatusImageView.image = [UIImage imageNamed:@"downloadable-22"];
        
        self.downloadStatusImageView.hidden = downloadsHintsHidden ? YES : ! [Download canDownloadMedia:self.media];
        return;
    }
    
    self.downloadStatusImageView.hidden = NO;
    
    UIImage *downloadImage = nil;
    UIColor *tintColor = UIColor.play_lightGrayColor;
    
    switch (download.state) {
        case DownloadStateAdded:
        case DownloadStateDownloadingSuspended: {
            [self.downloadStatusImageView play_stopAnimating];
            downloadImage = [UIImage imageNamed:@"downloadable_stop-22"];
            break;
        }
            
        case DownloadStateDownloading: {
            [self.downloadStatusImageView play_startAnimatingDownloading22WithTintColor:tintColor];
            downloadImage = self.downloadStatusImageView.image;
            break;
        }
            
        case DownloadStateDownloaded: {
            [self.downloadStatusImageView play_stopAnimating];
            downloadImage = [UIImage imageNamed:@"downloadable_full-22"];
            break;
        }
            
        case DownloadStateDownloadable:
        case DownloadStateRemoved: {
            [self.downloadStatusImageView play_stopAnimating];
            downloadImage = [UIImage imageNamed:@"downloadable-22"];
            break;
        }
            
        default: {
            [self.downloadStatusImageView play_stopAnimating];
            break;
        }
    }
    
    self.downloadStatusImageView.image = downloadImage;
    self.downloadStatusImageView.tintColor = tintColor;
}

- (void)updateHistoryStatus
{
    HistoryPlaybackProgressForMediaMetadataAsync(self.media, ^(float progress) {
        self.progressView.hidden = (progress == 0.f);
        self.progressView.progress = progress;
    });
}

#pragma mark Previewing protocol

- (id)previewObject
{
    return (! self.editing) ? self.media : nil;
}

#pragma mark Notifications

- (void)downloadStateDidChange:(NSNotification *)notification
{
    [self updateDownloadStatus];
}

- (void)historyDidChange:(NSNotification *)notification
{
    NSArray<NSString *> *updatedURNs = notification.userInfo[SRGHistoryChangedUidsKey];
    if (self.media && [updatedURNs containsObject:self.media.URN]) {
        [self updateHistoryStatus];
    }
}

@end
