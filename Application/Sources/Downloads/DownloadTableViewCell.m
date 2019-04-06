//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "DownloadTableViewCell.h"

#import "AnalyticsConstants.h"
#import "Favorite.h"
#import "History.h"
#import "NSBundle+PlaySRG.h"
#import "NSDateFormatter+PlaySRG.h"
#import "NSString+PlaySRG.h"
#import "UIColor+PlaySRG.h"
#import "UIImage+PlaySRG.h"
#import "UIImageView+PlaySRG.h"
#import "UIColor+PlaySRG.h"
#import "UILabel+PlaySRG.h"

#import <CoconutKit/CoconutKit.h>
#import <libextobjc/libextobjc.h>
#import <SRGAnalytics/SRGAnalytics.h>
#import <SRGAppearance/SRGAppearance.h>
#import <SRGUserData/SRGUserData.h>

@interface DownloadTableViewCell ()

@property (nonatomic, weak) IBOutlet UILabel *titleLabel;
@property (nonatomic, weak) IBOutlet UILabel *subtitleLabel;
@property (nonatomic, weak) IBOutlet UIImageView *thumbnailImageView;
@property (nonatomic, weak) IBOutlet UILabel *durationLabel;
@property (nonatomic, weak) IBOutlet UIImageView *youthProtectionColorImageView;
@property (nonatomic, weak) IBOutlet UIImageView *favoriteImageView;
@property (nonatomic, weak) IBOutlet UIImageView *downloadStatusImageView;
@property (nonatomic, weak) IBOutlet UIImageView *media360ImageView;

@property (nonatomic, weak) IBOutlet UIProgressView *progressView;

@property (nonatomic) UIColor *durationLabelBackgroundColor;
@property (nonatomic) UIColor *favoriteImageViewBackgroundColor;

@end

@implementation DownloadTableViewCell

#pragma mark Overrides

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.backgroundColor = UIColor.play_blackColor;
    
    UIView *colorView = [[UIView alloc] init];
    colorView.backgroundColor = UIColor.play_blackColor;
    self.selectedBackgroundView = colorView;
    
    self.thumbnailImageView.backgroundColor = UIColor.play_grayThumbnailImageViewBackgroundColor;
    
    self.favoriteImageView.backgroundColor = UIColor.play_redColor;
    self.favoriteImageView.hidden = YES;
    
    self.favoriteImageViewBackgroundColor = self.favoriteImageView.backgroundColor;
    self.durationLabelBackgroundColor = self.durationLabel.backgroundColor;
    
    self.youthProtectionColorImageView.hidden = YES;
    
    self.media360ImageView.layer.shadowOpacity = 0.3f;
    self.media360ImageView.layer.shadowRadius = 2.f;
    self.media360ImageView.layer.shadowOffset = CGSizeMake(0.f, 1.f);
    
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
    
    self.favoriteImageView.hidden = YES;
    self.progressView.hidden = YES;
    
    [self.thumbnailImageView play_resetImage];
}

- (void)willMoveToWindow:(UIWindow *)window
{
    [super willMoveToWindow:window];
    
    if (window) {
        [self updateFavoriteStatus];
        [self updateDownloadStatus];
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(favoriteStateDidChange:)
                                                   name:FavoriteStateDidChangeNotification
                                                 object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(historyDidChange:)
                                                   name:SRGHistoryDidChangeNotification
                                                 object:SRGUserData.currentUserData.history];
    }
    else {
        [NSNotificationCenter.defaultCenter removeObserver:self name:FavoriteStateDidChangeNotification object:nil];
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
        self.favoriteImageView.backgroundColor = self.favoriteImageViewBackgroundColor;
        self.durationLabel.backgroundColor = self.durationLabelBackgroundColor;
    }
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    
    if (self.editing) {
        [self updateDownloadStatus];
        self.favoriteImageView.backgroundColor = self.favoriteImageViewBackgroundColor;
        self.durationLabel.backgroundColor = self.durationLabelBackgroundColor;
    }
}

#pragma mark Accessibility

- (NSString *)accessibilityLabel
{
    NSMutableString *accessibilityLabel = [self.download.title mutableCopy];
    
    SRGShow *show = self.download.media.show;
    if (show.title && ! [show.title isEqualToString:self.download.title]) {
        [accessibilityLabel appendFormat:@", %@", show.title];
    }
    
    NSString *youthProtectionAccessibilityLabel = SRGAccessibilityLabelForYouthProtectionColor(self.download.youthProtectionColor);
    if (self.youthProtectionColorImageView.image && youthProtectionAccessibilityLabel) {
        [accessibilityLabel appendFormat:@". %@", youthProtectionAccessibilityLabel];
    }
    
    return [accessibilityLabel copy];
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
    
    self.youthProtectionColorImageView.image = YouthProtectionImageForColor(download.youthProtectionColor);
    self.youthProtectionColorImageView.hidden = (self.youthProtectionColorImageView.image == nil);
    
    self.subtitleLabel.numberOfLines = (self.durationLabel.hidden) ? 3 : 1;
    
    [self.thumbnailImageView play_requestImageForObject:download.media withScale:ImageScaleSmall type:SRGImageTypeDefault placeholder:ImagePlaceholderMedia unavailabilityHandler:^{
        [self.thumbnailImageView play_requestImageForObject:download withScale:ImageScaleSmall type:SRGImageTypeDefault placeholder:ImagePlaceholderMedia];
    }];
    
    [self updateFavoriteStatus];
    [self updateDownloadStatus];
    [self updateHistoryStatus];
}

#pragma mark UI

- (void)updateFavoriteStatus
{
    self.favoriteImageView.hidden = ([Favorite favoriteForMedia:self.download.media] == nil);
}

- (void)updateDownloadStatus
{
    UIImage *downloadImage = nil;
    UIColor *tintColor = (self.editing && (self.selected || self.highlighted)) ? UIColor.redColor : UIColor.play_lightGrayColor;
    
    self.subtitleLabel.text = [NSDateFormatter.play_relativeDateAndTimeFormatter stringFromDate:self.download.date].play_localizedUppercaseFirstLetterString;
    self.subtitleLabel.font = [UIFont srg_lightFontWithTextStyle:SRGAppearanceFontTextStyleSubtitle];
    
    switch (self.download.state) {
        case DownloadStateAdded:
        case DownloadStateDownloadingSuspended: {
            [self.downloadStatusImageView play_stopAnimating];
            downloadImage = [UIImage imageNamed:@"downloadable_stop-22"];
            break;
        }
            
        case DownloadStateDownloading: {
            [self.downloadStatusImageView play_startAnimatingDownloading22WithTintColor:tintColor];
            NSProgress *progress = ([Download currentlyKnownProgressForDownload:self.download]) ?: [NSProgress progressWithTotalUnitCount:10]; // Display 0% if nothing
            self.subtitleLabel.text = [progress localizedDescription];
            downloadImage = self.downloadStatusImageView.image;
            break;
        }
            
        case DownloadStateDownloaded: {
            [self.downloadStatusImageView play_stopAnimating];
            self.subtitleLabel.text = [NSByteCountFormatter stringFromByteCount:self.download.size countStyle:NSByteCountFormatterCountStyleFile];
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
    HistoryPlaybackProgressForMediaMetadataAsync(self.download, ^(float progress) {
        self.progressView.hidden = (progress == 0.f);
        self.progressView.progress = progress;
    });
}

#pragma mark Previewing protocol

- (id)previewObject
{
    return (! self.editing) ? self.download.media : nil;
}

#pragma mark Notifications

- (void)favoriteStateDidChange:(NSNotification *)notification
{
    [self updateFavoriteStatus];
}

- (void)downloadStateDidChange:(NSNotification *)notification
{
    [self updateDownloadStatus];
}

- (void)downloadProgressDidChange:(NSNotification *)notification
{
    NSProgress *progress = notification.userInfo[DownloadProgressKey];
    self.subtitleLabel.text = progress.localizedDescription;
}

- (void)historyDidChange:(NSNotification *)notification
{
    NSArray<NSString *> *updatedURNs = notification.userInfo[SRGHistoryChangedUidsKey];
    if (self.download && [updatedURNs containsObject:self.download.URN]) {
        [self updateHistoryStatus];
    }
}

@end
