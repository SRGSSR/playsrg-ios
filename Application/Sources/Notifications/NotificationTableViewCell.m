//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "NotificationTableViewCell.h"

#import "NSDateFormatter+PlaySRG.h"
#import "UIColor+PlaySRG.h"
#import "UIImage+PlaySRG.h"
#import "UIImageView+PlaySRG.h"
#import "UILabel+PlaySRG.h"

#import <libextobjc/libextobjc.h>
#import <SRGAppearance/SRGAppearance.h>

@interface NotificationTableViewCell ()

@property (nonatomic, weak) IBOutlet UILabel *titleLabel;
@property (nonatomic, weak) IBOutlet UILabel *subtitleLabel;
@property (nonatomic, weak) IBOutlet UIImageView *thumbnailImageView;
@property (nonatomic, weak) IBOutlet UILabel *dateLabel;

@property (nonatomic, weak) IBOutlet UILabel *unreadLabel;

@property (nonatomic) MGSwipeButton *deleteButton;

@end

@implementation NotificationTableViewCell

#pragma mark Overrides

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    UIColor *backgroundColor = UIColor.play_blackColor;
    self.backgroundColor = backgroundColor;
    
    UIView *colorView = [[UIView alloc] init];
    colorView.backgroundColor = backgroundColor;
    self.selectedBackgroundView = colorView;
    
    self.thumbnailImageView.backgroundColor = UIColor.play_grayThumbnailImageViewBackgroundColor;
    
    self.subtitleLabel.backgroundColor = backgroundColor;
    self.subtitleLabel.textColor = UIColor.play_lightGrayColor;
    
    self.dateLabel.backgroundColor = backgroundColor;
    self.dateLabel.textColor = UIColor.play_lightGrayColor;
    
    self.unreadLabel.backgroundColor = backgroundColor;
    self.unreadLabel.textColor = UIColor.play_notificationRedColor;
    
    @weakify(self)
    self.deleteButton = [MGSwipeButton buttonWithTitle:@"" icon:[UIImage imageNamed:@"delete-22"] backgroundColor:UIColor.redColor callback:^BOOL(MGSwipeTableCell * _Nonnull cell) {
        @strongify(self)
        [Notification removeNotification:self.notification];
        [self.cellDelegate notificationTableViewCell:self willDeleteNotification:self.notification];
        return YES;
    }];
    self.deleteButton.tintColor = UIColor.whiteColor;
    self.deleteButton.buttonWidth = 60.f;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    [self.thumbnailImageView play_resetImage];
}

-(void)setCellDelegate:(id<NotificationTableViewCellDelegate>)cellDelegate
{
    _cellDelegate = cellDelegate;
    self.rightButtons = cellDelegate ? @[ self.deleteButton ] : nil;
}

#pragma mark Accessibility

- (NSString *)accessibilityLabel
{
    return [self.notification.title stringByAppendingFormat:@", %@", self.notification.body];
}

#pragma mark Getters and setters

- (void)setNotification:(Notification *)notification
{
    _notification = notification;
    
    self.titleLabel.text = notification.title;
    self.titleLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleBody];
    
    self.unreadLabel.hidden = notification.read;
    
    self.subtitleLabel.text = notification.body;
    self.subtitleLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleSubtitle];
    
    self.dateLabel.text = [NSDateFormatter.play_relativeDateAndTimeFormatter stringFromDate:notification.date];
    self.dateLabel.font = [UIFont srg_lightFontWithTextStyle:SRGAppearanceFontTextStyleSubtitle];
    
    ImagePlaceholder imagePlaceholder = ImagePlaceholderNotification;
    if (notification.mediaURN) {
        imagePlaceholder = ImagePlaceholderMedia;
    }
    else if (notification.showURN) {
        imagePlaceholder = ImagePlaceholderMediaList;
    }
    
    [self.thumbnailImageView play_requestImageForObject:notification withScale:ImageScaleSmall type:SRGImageTypeDefault placeholder:imagePlaceholder];
}

@end
