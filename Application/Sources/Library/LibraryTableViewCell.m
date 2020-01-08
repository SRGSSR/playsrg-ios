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

#import <PPBadgeView/PPBadgeView.h>
#import <SRGAppearance/SRGAppearance.h>

@interface LibraryTableViewCell ()

@property (nonatomic, weak) IBOutlet UIImageView *iconImageView;
@property (nonatomic, weak) IBOutlet UILabel *titleLabel;

@end

@implementation LibraryTableViewCell

#pragma mark Getters and setters

- (void)setMenuItemInfo:(MenuItemInfo *)menuItemInfo
{
    _menuItemInfo = menuItemInfo;
    
    self.titleLabel.font = [UIFont srg_regularFontWithTextStyle:SRGAppearanceFontTextStyleHeadline];
    self.titleLabel.text = menuItemInfo.title;
    
    self.iconImageView.image = menuItemInfo.image;
    [self updateIconImageViewAnimation];
    [self updateIconImageViewBadge];
}

#pragma mark Overrides

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    UIColor *backgroundColor = UIColor.blackColor;
    self.backgroundColor = backgroundColor;
    
    self.titleLabel.backgroundColor = backgroundColor;
    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    [self.iconImageView play_stopAnimating];
    [self.iconImageView pp_hiddenBadge];
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
    UIColor *color = highlighted ? UIColor.whiteColor : UIColor.play_grayColor;
    self.titleLabel.textColor = color;
    self.iconImageView.tintColor = color;
}

- (void)updateIconImageViewAnimation
{
    [self.iconImageView play_stopAnimating];
    
    if (self.menuItemInfo.menuItem == MenuItemDownloads) {
        switch (DownloadSession.sharedDownloadSession.state) {
            case DownloadSessionStateDownloading: {
                [self.iconImageView play_startAnimatingDownloading22WithTintColor:self.iconImageView.tintColor];
                break;
            }
                
            default: {
                break;
            }
        }
        self.iconImageView.image = self.menuItemInfo.image;
    }
}

- (void)updateIconImageViewBadge
{
    if (@available(iOS 10, *)) {
        if (self.menuItemInfo.menuItem == MenuItemNotifications && PushService.sharedService.enabled) {
            NSInteger badgeNumber = UIApplication.sharedApplication.applicationIconBadgeNumber;
            if (badgeNumber != 0) {
                NSString *badgeText = (badgeNumber > 99) ? @"99+" : @(badgeNumber).stringValue;
                [self.iconImageView pp_addBadgeWithText:badgeText];
                [self.iconImageView pp_moveBadgeWithX:-6.f Y:7.f];
                [self.iconImageView pp_setBadgeHeight:14.f];
                [self.iconImageView pp_setBadgeLabelAttributes:^(PPBadgeLabel *badgeLabel) {
                    badgeLabel.font = [UIFont boldSystemFontOfSize:13.f];
                    badgeLabel.backgroundColor = UIColor.play_notificationRedColor;
                }];
            }
        }
    }
}

#pragma mark Notifications

- (void)downloadSessionStateDidChange:(NSNotification *)notification
{
    [self updateIconImageViewAnimation];
}

@end
