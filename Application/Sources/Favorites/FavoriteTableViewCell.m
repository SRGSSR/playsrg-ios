//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "FavoriteTableViewCell.h"

#import "AnalyticsConstants.h"
#import "ApplicationConfiguration.h"
#import "Download.h"
#import "History.h"
#import "NSBundle+PlaySRG.h"
#import "NSDateFormatter+PlaySRG.h"
#import "NSString+PlaySRG.h"
#import "PushService.h"
#import "UIColor+PlaySRG.h"
#import "UIImage+PlaySRG.h"
#import "UIImageView+PlaySRG.h"
#import "UILabel+PlaySRG.h"

#import <CoconutKit/CoconutKit.h>
#import <libextobjc/libextobjc.h>
#import <SRGAnalytics/SRGAnalytics.h>
#import <SRGAppearance/SRGAppearance.h>
#import <SRGUserData/SRGUserData.h>

@interface FavoriteTableViewCell ()

@property (nonatomic, weak) IBOutlet UILabel *titleLabel;
@property (nonatomic, weak) IBOutlet UILabel *subtitleLabel;
@property (nonatomic, weak) IBOutlet UIImageView *thumbnailImageView;
@property (nonatomic, weak) IBOutlet UILabel *durationLabel;
@property (nonatomic, weak) IBOutlet UIImageView *youthProtectionColorImageView;
@property (nonatomic, weak) IBOutlet UIImageView *favoriteImageView;
@property (nonatomic, weak) IBOutlet UIView *gradientView;
@property (nonatomic, weak) IBOutlet UIImageView *subscriptionImageView;
@property (nonatomic, weak) IBOutlet UIImageView *downloadStatusImageView;
@property (nonatomic, weak) IBOutlet UIImageView *media360ImageView;

@property (nonatomic, weak) IBOutlet UIView *blockingOverlayView;
@property (nonatomic, weak) IBOutlet UIImageView *blockingReasonImageView;

@property (nonatomic, weak) IBOutlet UIProgressView *progressView;

@property (nonatomic) UIColor *durationLabelBackgroundColor;
@property (nonatomic) UIColor *favoriteImageViewBackgroundColor;

@property (nonatomic, weak) SRGRequest *objectRequest;

@end

@implementation FavoriteTableViewCell

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
    
    self.youthProtectionColorImageView.hidden = YES;
    
    self.favoriteImageView.backgroundColor = UIColor.play_redColor;
    self.durationLabel.backgroundColor = UIColor.play_blackDurationLabelBackgroundColor;
    
    self.favoriteImageViewBackgroundColor = self.favoriteImageView.backgroundColor;
    self.durationLabelBackgroundColor = self.durationLabel.backgroundColor;
    
    self.subscriptionImageView.layer.shadowOpacity = 0.3f;
    self.subscriptionImageView.layer.shadowRadius = 2.f;
    self.subscriptionImageView.layer.shadowOffset = CGSizeMake(0.f, 1.f);
    
    self.media360ImageView.layer.shadowOpacity = 0.3f;
    self.media360ImageView.layer.shadowRadius = 2.f;
    self.media360ImageView.layer.shadowOffset = CGSizeMake(0.f, 1.f);
    
    self.progressView.progressTintColor = UIColor.play_progressRedColor;
    
    self.downloadStatusImageView.tintColor = UIColor.play_lightGrayColor;
    
    @weakify(self)
    MGSwipeButton *deleteButton = [MGSwipeButton buttonWithTitle:@"" icon:[UIImage imageNamed:@"delete-22"] backgroundColor:UIColor.redColor callback:^BOOL(MGSwipeTableCell * _Nonnull cell) {
        @strongify(self)
        
        [Favorite removeFavorite:self.favorite];
        
        SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
        labels.value = (self.favorite.type == FavoriteTypeShow) ? self.favorite.showURN : self.favorite.mediaURN;
        labels.source = AnalyticsSourceSwipe;
        [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleHistoryRemove labels:labels];
        
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

- (void)willMoveToWindow:(UIWindow *)window
{
    [super willMoveToWindow:window];
    
    if (window) {
        // Ensure proper state when the view is reinserted
        [self updateDownloadStatus];
        [self updateSubscriptionStatus];
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(downloadStateDidChange:)
                                                   name:DownloadStateDidChangeNotification
                                                 object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(subscriptionStateDidChange:)
                                                   name:PushServiceSubscriptionStateDidChangeNotification
                                                 object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(historyDidChange:)
                                                   name:SRGHistoryDidChangeNotification
                                                 object:SRGUserData.currentUserData.history];
    }
    else {
        [self.objectRequest cancel];
        
        [NSNotificationCenter.defaultCenter removeObserver:self name:DownloadStateDidChangeNotification object:nil];
        [NSNotificationCenter.defaultCenter removeObserver:self name:PushServiceSubscriptionStateDidChangeNotification object:nil];
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
        self.favoriteImageView.backgroundColor = self.favoriteImageViewBackgroundColor;
        self.durationLabel.backgroundColor = self.durationLabelBackgroundColor;
    }
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    
    if (self.editing) {
        self.favoriteImageView.backgroundColor = self.favoriteImageViewBackgroundColor;
        self.durationLabel.backgroundColor = self.durationLabelBackgroundColor;
    }
}

#pragma mark Accessibility

- (NSString *)accessibilityLabel
{
    if (self.favorite.mediaContentType == FavoriteMediaContentTypeLive) {
        return [NSString stringWithFormat:PlaySRGAccessibilityLocalizedString(@"%@ live", @"Live content label, with a media title"), self.favorite.title];
    }
    else {
        NSMutableString *accessibilityLabel = [self.favorite.title mutableCopy];
        
        NSString *showTitle = self.favorite.showTitle;
        if (showTitle && ! [showTitle isEqualToString:self.favorite.title]) {
            [accessibilityLabel appendFormat:@", %@", showTitle];
        }
        
        NSString *youthProtectionAccessibilityLabel = SRGAccessibilityLabelForYouthProtectionColor(self.favorite.youthProtectionColor);
        if (self.youthProtectionColorImageView.image && youthProtectionAccessibilityLabel) {
            [accessibilityLabel appendFormat:@". %@", youthProtectionAccessibilityLabel];
        }
        
        return [accessibilityLabel copy];
    }
}

- (NSString *)accessibilityHint
{
    return self.favorite.type == FavoriteTypeShow ? PlaySRGAccessibilityLocalizedString(@"Opens show details.", @"Show cell action hint") : PlaySRGAccessibilityLocalizedString(@"Plays the content.", @"Media cell hint") ;
}

#pragma mark Getters and setters

- (void)setFavorite:(Favorite *)favorite
{
    _favorite = favorite;
    
    self.backgroundColor = (favorite.type == FavoriteTypeShow) ? UIColor.play_grayThumbnailImageViewBackgroundColor : UIColor.play_blackColor;
    self.selectedBackgroundView.backgroundColor = (favorite.type == FavoriteTypeShow) ? UIColor.play_grayThumbnailImageViewBackgroundColor : UIColor.play_blackColor;
    
    self.titleLabel.text = favorite.title;
    self.titleLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleBody];
    
    if (favorite.mediaContentType != FavoriteMediaContentTypeLive) {
        NSString *showTitle = favorite.showTitle;
        if (showTitle && ! [showTitle isEqualToString:favorite.title]) {
            NSMutableAttributedString *subtitle = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ - ", showTitle]
                                                                                         attributes:@{ NSFontAttributeName : [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleSubtitle] }];
            
            [subtitle appendAttributedString:[[NSAttributedString alloc] initWithString:[NSDateFormatter.play_relativeDateFormatter stringFromDate:favorite.date].play_localizedUppercaseFirstLetterString
                                                                             attributes:@{ NSFontAttributeName : [UIFont srg_lightFontWithTextStyle:SRGAppearanceFontTextStyleSubtitle] }]];
            
            self.subtitleLabel.attributedText = [subtitle copy];
        }
        else {
            self.subtitleLabel.font = [UIFont srg_lightFontWithTextStyle:SRGAppearanceFontTextStyleSubtitle];
            self.subtitleLabel.text = [NSDateFormatter.play_relativeDateAndTimeFormatter stringFromDate:favorite.date].play_localizedUppercaseFirstLetterString;
        }
    }
    else {
        self.subtitleLabel.text = nil;
    }
    
    [self.durationLabel play_displayDurationLabelForFavorite:favorite];
    
    self.media360ImageView.hidden = (favorite.presentation != SRGPresentation360);
    
    self.youthProtectionColorImageView.image = YouthProtectionImageForColor(favorite.youthProtectionColor);
    self.youthProtectionColorImageView.hidden = (self.youthProtectionColorImageView.image == nil);
    
    self.thumbnailImageView.backgroundColor = (favorite.type == FavoriteTypeShow) ? UIColor.play_blackColor :UIColor.play_grayThumbnailImageViewBackgroundColor;
    
    SRGBlockingReason blockingReason = [favorite blockingReasonAtDate:NSDate.date];
    if (blockingReason == SRGBlockingReasonNone || blockingReason == SRGBlockingReasonStartDate) {
        self.blockingOverlayView.hidden = YES;
        
        self.titleLabel.textColor = UIColor.whiteColor;
    }
    else {
        self.blockingOverlayView.hidden = NO;
        self.blockingReasonImageView.image = [UIImage play_imageForBlockingReason:blockingReason];
        
        self.titleLabel.textColor = UIColor.play_lightGrayColor;
    }
    
    BOOL available = NO;
    self.objectRequest = [self.favorite objectForType:FavoriteTypeUnspecified available:&available withCompletionBlock:^(id  _Nullable favoritedObject, NSError * _Nullable error) {
        id<SRGImage> imageObject = favoritedObject;
        if ([favoritedObject isKindOfClass:SRGMedia.class]) {
            SRGMedia *media = favoritedObject;
            if (media.contentType == SRGContentTypeLivestream && media.channel) {
                imageObject = media.channel;
            }
        }
        
        [self.thumbnailImageView play_requestImageForObject:imageObject withScale:ImageScaleSmall type:SRGImageTypeDefault placeholder:(favorite.type == FavoriteTypeShow) ? ImagePlaceholderMediaList : ImagePlaceholderMedia];
    }];
    
    if (! available) {
        [self.thumbnailImageView play_requestImageForObject:favorite withScale:ImageScaleSmall type:SRGImageTypeDefault placeholder:(favorite.type == FavoriteTypeShow) ? ImagePlaceholderMediaList : ImagePlaceholderMedia];
    }
    
    [self updateDownloadStatus];
    [self updateSubscriptionStatus];
    [self updateHistoryStatus];
}

#pragma mark UI

- (void)updateDownloadStatus
{
    self.downloadStatusImageView.hidden = YES;
    
    [self.favorite objectForType:FavoriteTypeMedia available:NULL withCompletionBlock:^(SRGMedia * _Nullable media, NSError * _Nullable error) {
        Download *download = [Download downloadForMedia:media];
        if (! download) {
            BOOL downloadsHintsHidden = ApplicationConfiguration.sharedApplicationConfiguration.downloadsHintsHidden;
            
            [self.downloadStatusImageView play_stopAnimating];
            self.downloadStatusImageView.image = [UIImage imageNamed:@"downloadable-22"];
            
            self.downloadStatusImageView.hidden = downloadsHintsHidden ? YES : ! [Download canDownloadMedia:media];
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
    }];
}

- (void)updateSubscriptionStatus
{
    self.subscriptionImageView.hidden = YES;
    self.gradientView.hidden = YES;
    
    [self.favorite objectForType:FavoriteTypeShow available:NULL withCompletionBlock:^(SRGShow * _Nullable show, NSError * _Nullable error) {
        BOOL subscribed = [PushService.sharedService isSubscribedToShow:show];
        self.subscriptionImageView.hidden = ! subscribed;
        self.gradientView.hidden = ! subscribed;
    }];
}

- (void)updateHistoryStatus
{
    float progress = HistoryPlaybackProgressForFavorite(self.favorite);
    self.progressView.hidden = (progress == 0.f);
    self.progressView.progress = progress;
}

#pragma mark Previewing protocol

- (id)previewObject
{
    // Return the object if readily available (otherwise will be fetched asynchronously for migration and returned
    // the next time)
    __block id previewObject = nil;
    [self.favorite objectForType:FavoriteTypeUnspecified available:NULL withCompletionBlock:^(SRGMedia * _Nullable media, NSError * _Nullable error) {
        previewObject = media;
    }];
    return (! self.editing) ? previewObject : nil;
}

#pragma mark Notifications

- (void)downloadStateDidChange:(NSNotification *)notification
{
    [self updateDownloadStatus];
}

- (void)subscriptionStateDidChange:(NSNotification *)notification
{
    [self updateSubscriptionStatus];
}

- (void)historyDidChange:(NSNotification *)notification
{
    NSArray<NSString *> *updatedURNs = notification.userInfo[SRGHistoryChangedUidsKey];
    if (self.favorite && [updatedURNs containsObject:self.favorite.mediaURN]) {
        [self updateHistoryStatus];
    }
}

@end
