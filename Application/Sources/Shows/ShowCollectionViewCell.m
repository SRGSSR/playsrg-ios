//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "ShowCollectionViewCell.h"

#import "AnalyticsConstants.h"
#import "Banner.h"
#import "NSBundle+PlaySRG.h"
#import "PushService.h"
#import "UIColor+PlaySRG.h"
#import "UIImage+PlaySRG.h"
#import "UIImageView+PlaySRG.h"

#import <CoconutKit/CoconutKit.h>
#import <SRGAnalytics/SRGAnalytics.h>
#import <SRGAppearance/SRGAppearance.h>

@interface ShowCollectionViewCell ()

@property (nonatomic, weak) IBOutlet UIView *showView;
@property (nonatomic, weak) IBOutlet UIView *placeholderView;
@property (nonatomic, weak) IBOutlet UIImageView *placeholderImageView;

@property (nonatomic, weak) IBOutlet UIImageView *thumbnailImageView;
@property (nonatomic, weak) IBOutlet UIView *gradientView;
@property (nonatomic, weak) IBOutlet UIImageView *subscriptionImageView;
@property (nonatomic, weak) IBOutlet UILabel *titleLabel;

@end

@implementation ShowCollectionViewCell

#pragma mark Overrides

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.backgroundColor = UIColor.play_blackColor;
    
    self.showView.alpha = 0.f;
    self.placeholderView.alpha = 1.f;
    
    // Accommodate all kinds of usages (medium or small)
    self.placeholderImageView.image = [UIImage play_vectorImageAtPath:FilePathForImagePlaceholder(ImagePlaceholderMedia)
                                                            withScale:ImageScaleMedium];
    
    self.thumbnailImageView.backgroundColor = UIColor.play_grayThumbnailImageViewBackgroundColor;
    
    self.subscriptionImageView.layer.shadowOpacity = 0.3f;
    self.subscriptionImageView.layer.shadowRadius = 2.f;
    self.subscriptionImageView.layer.shadowOffset = CGSizeMake(0.f, 1.f);
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    self.showView.alpha = 0.f;
    self.placeholderView.alpha = 1.f;
    
    [self.thumbnailImageView play_resetImage];
}

- (void)willMoveToWindow:(UIWindow *)newWindow
{
    [super willMoveToWindow:newWindow];
    
    if (newWindow) {
        // Ensure proper state when the view is reinserted
        [self updateSubscriptionStatus];
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(subscriptionStateDidChange:)
                                                   name:PushServiceSubscriptionStateDidChangeNotification
                                                 object:nil];
    }
    else {
        [NSNotificationCenter.defaultCenter removeObserver:self name:PushServiceSubscriptionStateDidChangeNotification object:nil];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    
    [self.nearestViewController registerForPreviewingWithDelegate:self.nearestViewController sourceView:self];
}

#pragma mark Accessibility

- (BOOL)isAccessibilityElement
{
    return YES;
}

- (NSString *)accessibilityLabel
{
    return self.show.title;
}

- (NSString *)accessibilityHint
{
    return PlaySRGAccessibilityLocalizedString(@"Opens show details.", @"Show cell hint");
}

#pragma mark Getters and setters

- (void)setShow:(SRGShow *)show
{
    _show = show;
    
    if (! show) {
        self.showView.alpha = 0.f;
        self.placeholderView.alpha = 1.f;
        return;
    }
    
    self.showView.alpha = 1.f;
    self.placeholderView.alpha = 0.f;
    
    self.titleLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleBody];
    self.titleLabel.text = show.title;
    
    [self.thumbnailImageView play_requestImageForObject:show withScale:ImageScaleSmall type:SRGImageTypeDefault placeholder:ImagePlaceholderMediaList];
    
    [self updateSubscriptionStatus];
}

#pragma mark UI

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
    return self.show;
}

#pragma mark Notifications

- (void)subscriptionStateDidChange:(NSNotification *)notification
{
    [self updateSubscriptionStatus];
}

@end
