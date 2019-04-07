//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SubscriptionTableViewCell.h"

#import "AnalyticsConstants.h"
#import "Favorite.h"
#import "PushService.h"
#import "UIColor+PlaySRG.h"
#import "UIImageView+PlaySRG.h"

#import <CoconutKit/CoconutKit.h>
#import <libextobjc/libextobjc.h>
#import <SRGAnalytics/SRGAnalytics.h>
#import <SRGAppearance/SRGAppearance.h>

@interface SubscriptionTableViewCell ()

@property (nonatomic, weak) IBOutlet UILabel *titleLabel;
@property (nonatomic, weak) IBOutlet UIImageView *thumbnailImageView;
@property (nonatomic, weak) IBOutlet UIImageView *favoriteImageView;
@property (nonatomic, weak) IBOutlet UIView *gradientView;
@property (nonatomic, weak) IBOutlet UIImageView *subscriptionImageView;

@property (nonatomic) UIColor *favoriteImageViewBackgroundColor;

@end

@implementation SubscriptionTableViewCell

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
    self.favoriteImageViewBackgroundColor = self.favoriteImageView.backgroundColor;
    
    self.subscriptionImageView.layer.shadowOpacity = 0.3f;
    self.subscriptionImageView.layer.shadowRadius = 2.f;
    self.subscriptionImageView.layer.shadowOffset = CGSizeMake(0.f, 1.f);
    
    @weakify(self)
    MGSwipeButton *deleteButton = [MGSwipeButton buttonWithTitle:@"" icon:[UIImage imageNamed:@"delete-22"] backgroundColor:UIColor.redColor callback:^BOOL(MGSwipeTableCell * _Nonnull cell) {
        @strongify(self)
        
        [PushService.sharedService unsubscribeFromShow:self.show];
        
        SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
        labels.value = self.show.URN;
        labels.source = AnalyticsSourceSwipe;
        [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleSubscriptionRemove labels:labels];
        
        return YES;
    }];
    deleteButton.tintColor = UIColor.whiteColor;
    deleteButton.buttonWidth = 60.f;
    self.rightButtons = @[deleteButton];
}

- (void)willMoveToWindow:(UIWindow *)window
{
    [super willMoveToWindow:window];
    
    if (window) {
        [self updateFavoriteStatus];
        [self updateSubscriptionStatus];
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(favoriteStateDidChange:)
                                                   name:FavoriteStateDidChangeNotification
                                                 object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(subscriptionStateDidChange:)
                                                   name:PushServiceSubscriptionStateDidChangeNotification
                                                 object:nil];
    }
    else {
        [NSNotificationCenter.defaultCenter removeObserver:self name:FavoriteStateDidChangeNotification object:nil];
        [NSNotificationCenter.defaultCenter removeObserver:self name:PushServiceSubscriptionStateDidChangeNotification object:nil];
    }
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    [self.thumbnailImageView play_resetImage];
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
    }
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    
    if (self.editing) {
        self.favoriteImageView.backgroundColor = self.favoriteImageViewBackgroundColor;
    }
}

#pragma mark Getters and setters

- (void)setShow:(SRGShow *)show
{
    _show = show;
    
    self.titleLabel.text = show.title;
    self.titleLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleBody];
    
    [self.thumbnailImageView play_requestImageForObject:show withScale:ImageScaleSmall type:SRGImageTypeDefault placeholder:ImagePlaceholderMediaList];
    
    [self updateFavoriteStatus];
    [self updateSubscriptionStatus];
}

#pragma mark UI

- (void)updateFavoriteStatus
{
    self.favoriteImageView.hidden = ([Favorite favoriteForShow:self.show] == nil);
}

- (void)updateSubscriptionStatus
{
    BOOL subscribed = [PushService.sharedService isSubscribedToShow:self.show];
    self.subscriptionImageView.image = [PushService.sharedService isPushNotificationSubscribedToShow:self.show] ? [UIImage imageNamed:@"notification_full_18"] :  [UIImage imageNamed:@"subscription_full-18"];
    self.subscriptionImageView.hidden = ! subscribed;
    self.gradientView.hidden = ! subscribed;
}

#pragma mark Previewing protocol

- (id)previewObject
{
    return (! self.editing) ? self.show : nil;
}

#pragma mark Notifications

- (void)favoriteStateDidChange:(NSNotification *)notification
{
    [self updateFavoriteStatus];
}

- (void)subscriptionStateDidChange:(NSNotification *)notification
{
    [self updateSubscriptionStatus];
}

@end
