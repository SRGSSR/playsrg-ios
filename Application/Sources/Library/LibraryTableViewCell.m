//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "LibraryTableViewCell.h"

#import "DownloadSession.h"
#import "PushService.h"
#import "UIColor+PlaySRG.h"
#import "UIImageView+PlaySRG.h"

#import <SRGAppearance/SRGAppearance.h>

@interface LibraryTableViewCell ()

@property (nonatomic, weak) IBOutlet UIImageView *iconImageView;
@property (nonatomic, weak) IBOutlet UILabel *titleLabel;

@end

@implementation LibraryTableViewCell

#pragma mark Getters and setters

- (void)setApplicationSectionInfo:(ApplicationSectionInfo *)applicationSectionInfo
{
    _applicationSectionInfo = applicationSectionInfo;
    
    self.titleLabel.font = [UIFont srg_regularFontWithTextStyle:SRGAppearanceFontTextStyleHeadline];
    self.titleLabel.text = applicationSectionInfo.title;
    
    self.iconImageView.image = applicationSectionInfo.image;
    [self updateIconImageViewAnimation];
}

#pragma mark Overrides

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    UIColor *backgroundColor = UIColor.play_blackColor;
    self.backgroundColor = backgroundColor;
    
    // Cell highlighting is custom
    self.selectionStyle = UITableViewCellSelectionStyleNone;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    [self.iconImageView play_stopAnimating];
}

- (void)willMoveToWindow:(UIWindow *)window
{
    [super willMoveToWindow:window];
    
    if (window) {
        [self updateIconImageViewAnimation];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(downloadSessionStateDidChange:)
                                                   name:DownloadSessionStateDidChangeNotification
                                                 object:nil];
    }
    else {
        [NSNotificationCenter.defaultCenter removeObserver:self name:DownloadSessionStateDidChangeNotification object:nil];
    }
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    
    [self updateAppearanceHighlighted:highlighted];
    [self updateIconImageViewAnimation];
}

#pragma mark User interface

- (void)updateAppearanceHighlighted:(BOOL)highlighted
{
    UIColor *color = highlighted ? UIColor.play_grayColor : UIColor.whiteColor;
    self.titleLabel.textColor = color;
    self.iconImageView.tintColor = color;
}

- (void)updateIconImageViewAnimation
{
    [self.iconImageView play_stopAnimating];
    
    if (self.applicationSectionInfo.applicationSection == ApplicationSectionDownloads) {
        switch (DownloadSession.sharedDownloadSession.state) {
            case DownloadSessionStateDownloading: {
                [self.iconImageView play_startAnimatingDownloading22WithTintColor:self.iconImageView.tintColor];
                break;
            }
                
            default: {
                break;
            }
        }
        self.iconImageView.image = self.applicationSectionInfo.image;
    }
}

#pragma mark Notifications

- (void)downloadSessionStateDidChange:(NSNotification *)notification
{
    [self updateIconImageViewAnimation];
}

@end
