//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "DownloadTableViewCell.h"

#import "AnalyticsConstants.h"
#import "History.h"
#import "Layout.h"
#import "NSBundle+PlaySRG.h"
#import "NSDateFormatter+PlaySRG.h"
#import "NSString+PlaySRG.h"
#import "SRGMedia+PlaySRG.h"
#import "UIColor+PlaySRG.h"
#import "UIImage+PlaySRG.h"
#import "UIImageView+PlaySRG.h"
#import "UIColor+PlaySRG.h"
#import "UILabel+PlaySRG.h"

@import libextobjc;
@import SRGAnalytics;
@import SRGAppearance;
@import SRGUserData;

@interface DownloadTableViewCell ()

@property (nonatomic, weak) IBOutlet UILabel *titleLabel;
@property (nonatomic, weak) IBOutlet UILabel *subtitleLabel;
@property (nonatomic, weak) IBOutlet UIView *thumbnailWrapperView;
@property (nonatomic, weak) IBOutlet UIImageView *thumbnailImageView;
@property (nonatomic, weak) IBOutlet UILabel *durationLabel;
@property (nonatomic, weak) IBOutlet UIImageView *youthProtectionColorImageView;
@property (nonatomic, weak) IBOutlet UIImageView *downloadStatusImageView;
@property (nonatomic, weak) IBOutlet UIImageView *media360ImageView;
@property (nonatomic, weak) IBOutlet UILabel *availabilityLabel;

@property (nonatomic, weak) IBOutlet UIProgressView *progressView;

@property (nonatomic) UIColor *durationLabelBackgroundColor;

@property (nonatomic, copy) NSString *progressTaskHandle;

@end

@implementation DownloadTableViewCell

#pragma mark Overrides

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.backgroundColor = UIColor.play_blackColor;
    
    UIView *selectedBackgroundView = [[UIView alloc] init];
    selectedBackgroundView.backgroundColor = UIColor.clearColor;
    self.selectedBackgroundView = selectedBackgroundView;
    
    self.thumbnailWrapperView.backgroundColor = UIColor.play_grayThumbnailImageViewBackgroundColor;
    self.thumbnailWrapperView.layer.cornerRadius = LayoutStandardViewCornerRadius;
    self.thumbnailWrapperView.layer.masksToBounds = YES;
    
    self.durationLabelBackgroundColor = self.durationLabel.backgroundColor;
    
    self.youthProtectionColorImageView.hidden = YES;
    self.availabilityLabel.hidden = YES;
    
    self.progressView.progressTintColor = UIColor.play_progressRedColor;
    
    self.downloadStatusImageView.tintColor = UIColor.play_lightGrayColor;
    
    @weakify(self)
    MGSwipeButton *deleteButton = [MGSwipeButton buttonWithTitle:@"" icon:[UIImage imageNamed:@"delete-22"] backgroundColor:UIColor.redColor callback:^BOOL(MGSwipeTableCell * _Nonnull cell) {
        @strongify(self)
        
        [Download removeDownload:self.download];
        
        SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
        labels.value = self.download.URN;
        labels.source = AnalyticsSourceSwipe;
        [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleDownloadRemove labels:labels];
        
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
    self.availabilityLabel.hidden = YES;
    
    self.progressView.hidden = YES;
    
    [self.thumbnailImageView play_resetImage];
}

- (void)willMoveToWindow:(UIWindow *)window
{
    [super willMoveToWindow:window];
    
    if (window) {
        [self updateDownloadStatus];
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(historyEntriesDidChange:)
                                                   name:SRGHistoryEntriesDidChangeNotification
                                                 object:SRGUserData.currentUserData.history];
    }
    else {
        [NSNotificationCenter.defaultCenter removeObserver:self name:SRGHistoryEntriesDidChangeNotification object:SRGUserData.currentUserData.history];
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
        self.durationLabel.backgroundColor = self.durationLabelBackgroundColor;
    }
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    
    if (self.editing) {
        [self updateDownloadStatus];
        self.durationLabel.backgroundColor = self.durationLabelBackgroundColor;
    }
}

#pragma mark Accessibility

- (BOOL)isAccessibilityElement
{
    return YES;
}

- (NSString *)accessibilityLabel
{
    NSMutableString *accessibilityLabel = self.download.title.mutableCopy;
    
    SRGShow *show = self.download.media.show;
    if (show.title && ! [show.title isEqualToString:self.download.title]) {
        [accessibilityLabel appendFormat:@", %@", show.title];
    }
    
    NSString *youthProtectionAccessibilityLabel = SRGAccessibilityLabelForYouthProtectionColor(self.download.youthProtectionColor);
    if (self.youthProtectionColorImageView.image && youthProtectionAccessibilityLabel) {
        [accessibilityLabel appendFormat:@". %@", youthProtectionAccessibilityLabel];
    }
    
    return accessibilityLabel.copy;
}

- (NSString *)accessibilityHint
{
    return PlaySRGAccessibilityLocalizedString(@"Plays the content.", @"Media cell hint") ;
}

#pragma mark Getters and setters

- (void)setDownload:(Download *)download
{
    if (_download) {
        [NSNotificationCenter.defaultCenter removeObserver:self name:DownloadStateDidChangeNotification object:_download];
        [NSNotificationCenter.defaultCenter removeObserver:self name:DownloadProgressDidChangeNotification object:_download];
    }
    
    _download = download;
    
    if (download) {
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(downloadStateDidChange:)
                                                   name:DownloadStateDidChangeNotification
                                                 object:download];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(downloadProgressDidChange:)
                                                   name:DownloadProgressDidChangeNotification
                                                 object:download];
    }
    
    self.titleLabel.text = download.title;
    self.titleLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleBody];
    
    [self.durationLabel play_displayDurationLabelForMediaMetadata:download];
    
    self.media360ImageView.hidden = (download.presentation != SRGPresentation360);
    
    BOOL isWebFirst = download.media.play_webFirst;
    BOOL isExpiringSoon = PlayTimeIntervalBeforeEnd(download.media) > DBL_MIN;
    self.availabilityLabel.hidden = ! isWebFirst && ! isExpiringSoon;
   
    [self.availabilityLabel play_setAvailabilityBadgeForMediaMetadata:download.media];
    
    // Have content fit in (almost) constant size vertically by reducing the title number of lines when a tag is displayed
    UIContentSizeCategory contentSizeCategory = UIApplication.sharedApplication.preferredContentSizeCategory;
    if (SRGAppearanceCompareContentSizeCategories(contentSizeCategory, UIContentSizeCategoryExtraLarge) == NSOrderedDescending) {
        self.titleLabel.numberOfLines = isWebFirst ? 1 : 2;
    }
    else {
        self.titleLabel.numberOfLines = 2;
    }
    
    self.youthProtectionColorImageView.image = YouthProtectionImageForColor(download.youthProtectionColor);
    self.youthProtectionColorImageView.hidden = (self.youthProtectionColorImageView.image == nil);
    
    self.subtitleLabel.numberOfLines = self.durationLabel.hidden ? 3 : 1;
    
    [self.thumbnailImageView play_requestImageForObject:download.media withScale:ImageScaleSmall type:SRGImageTypeDefault placeholder:ImagePlaceholderMedia unavailabilityHandler:^{
        [self.thumbnailImageView play_requestImageForObject:download withScale:ImageScaleSmall type:SRGImageTypeDefault placeholder:ImagePlaceholderMedia];
    }];
    
    [self updateDownloadStatus];
    [self updateHistoryStatus];
}

#pragma mark UI

- (void)updateDownloadStatus
{
    UIColor *tintColor = (self.editing && (self.selected || self.highlighted)) ? UIColor.redColor : UIColor.play_lightGrayColor;
    
    self.subtitleLabel.text = [NSDateFormatter.play_relativeDateAndTimeFormatter stringFromDate:self.download.date].play_localizedUppercaseFirstLetterString;
    self.subtitleLabel.font = [UIFont srg_lightFontWithTextStyle:SRGAppearanceFontTextStyleSubtitle];
    
    switch (self.download.state) {
        case DownloadStateAdded:
        case DownloadStateDownloadingSuspended: {
            [self.downloadStatusImageView stopAnimating];
            self.downloadStatusImageView.image = [UIImage imageNamed:@"downloadable_stop-16"];
            self.downloadStatusImageView.tintColor = tintColor;
            break;
        }
            
        case DownloadStateDownloading: {
            NSProgress *progress = [Download currentlyKnownProgressForDownload:self.download] ?: [NSProgress progressWithTotalUnitCount:10]; // Display 0% if nothing
            self.subtitleLabel.text = [progress localizedDescription];
            
            [self.downloadStatusImageView play_setDownloadAnimation16WithTintColor:tintColor];
            [self.downloadStatusImageView startAnimating];
            break;
        }
            
        case DownloadStateDownloaded: {
            self.subtitleLabel.text = [NSByteCountFormatter stringFromByteCount:self.download.size countStyle:NSByteCountFormatterCountStyleFile];
            
            [self.downloadStatusImageView stopAnimating];
            self.downloadStatusImageView.image = [UIImage imageNamed:@"downloadable_full-16"];
            self.downloadStatusImageView.tintColor = tintColor;
            break;
        }
            
        case DownloadStateDownloadable:
        case DownloadStateRemoved: {
            [self.downloadStatusImageView stopAnimating];
            self.downloadStatusImageView.image = [UIImage imageNamed:@"downloadable-16"];
            self.downloadStatusImageView.tintColor = tintColor;
            break;
        }
            
        default: {
            [self.downloadStatusImageView stopAnimating];
            self.downloadStatusImageView.image = nil;
            break;
        }
    }
}

- (void)updateHistoryStatus
{
    HistoryPlaybackProgressAsyncCancel(self.progressTaskHandle);
    self.progressTaskHandle = HistoryPlaybackProgressForMediaMetadataAsync(self.download, ^(float progress) {
        self.progressView.hidden = (progress == 0.f);
        self.progressView.progress = progress;
    });
}

#pragma mark Previewing protocol

- (id)previewObject
{
    return ! self.editing ? self.download.media : nil;
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

- (void)downloadProgressDidChange:(NSNotification *)notification
{
    NSProgress *progress = notification.userInfo[DownloadProgressKey];
    self.subtitleLabel.text = progress.localizedDescription;
}

- (void)historyEntriesDidChange:(NSNotification *)notification
{
    NSArray<NSString *> *updatedURNs = notification.userInfo[SRGHistoryEntriesUidsKey];
    if (self.download && [updatedURNs containsObject:self.download.URN]) {
        [self updateHistoryStatus];
    }
}

@end
