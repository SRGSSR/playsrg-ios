//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "ShowHeaderView.h"

#import "AnalyticsConstants.h"
#import "Banner.h"
#import "NSBundle+PlaySRG.h"
#import "PushService.h"
#import "UIImage+PlaySRG.h"
#import "UIImageView+PlaySRG.h"

#import <SRGAnalytics/SRGAnalytics.h>
#import <SRGAppearance/SRGAppearance.h>

// Choose the good aspect ratio for the logo image view, depending of the screen size
static const UILayoutPriority LogoImageViewAspectRatioConstraintNormalPriority = 900;
static const UILayoutPriority LogoImageViewAspectRatioConstraintLowPriority = 700;

@interface ShowHeaderView ()

@property (nonatomic, weak) IBOutlet UIImageView *logoImageView;
@property (nonatomic, weak) IBOutlet UILabel *titleLabel;
@property (nonatomic, weak) IBOutlet UILabel *subtitleLabel;
@property (nonatomic, weak) IBOutlet UIButton *subscriptionButton;
@property (nonatomic, weak) IBOutlet UIButton *notificationButton;

@property (nonatomic) IBOutlet NSLayoutConstraint *logoImageViewRatio16_9Constraint; // Need to retain it, because active state removes it
@property (nonatomic) IBOutlet NSLayoutConstraint *logoImageViewRatioBigLandscapeScreenConstraint; // Need to retain it, because active state removes it

@end

@implementation ShowHeaderView

#pragma mark Class methods

+ (CGFloat)heightForShow:(SRGShow *)show withSize:(CGSize)size
{
    // No header displayed on compact vertical layouts
    UITraitCollection *traitCollection = UIApplication.sharedApplication.keyWindow.traitCollection;
    if (traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact) {
        return 0.f;
    }
    
    ShowHeaderView *headerView = [NSBundle.mainBundle loadNibNamed:NSStringFromClass(self) owner:nil options:nil].firstObject;
    headerView.show = show;
    
    [headerView updateAspectRatioWithSize:size];
    
    // Force autolayout with correct frame width so that the layout is accurate
    headerView.frame = CGRectMake(CGRectGetMinX(headerView.frame), CGRectGetMinY(headerView.frame), size.width, CGRectGetHeight(headerView.frame));
    [headerView setNeedsLayout];
    [headerView layoutIfNeeded];
    
    // Return the minimum size which satisfies the constraints. Put a strong requirement on width and properly let the height
    // adjust
    // For an explanation, see http://titus.io/2015/01/13/a-better-way-to-autosize-in-ios-8.html
    CGSize fittingSize = UILayoutFittingCompressedSize;
    fittingSize.width = size.width;
    return [headerView systemLayoutSizeFittingSize:fittingSize
                     withHorizontalFittingPriority:UILayoutPriorityRequired
                           verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height;
}

#pragma mark Overrides

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.backgroundColor = UIColor.clearColor;
    
    // Accommodate all kinds of usages
    self.logoImageView.image = [UIImage play_vectorImageAtPath:FilePathForImagePlaceholder(ImagePlaceholderMediaList)
                                                     withScale:ImageScaleLarge];
}

- (void)layoutSubviews
{
    // To get a correct intrinsic size for a multiline label, we need to set its preferred max layout width
    // (also when using -systemLayoutSizeFittingSize:withHorizontalFittingPriority:verticalFittingPriority:)
    self.subtitleLabel.preferredMaxLayoutWidth = CGRectGetWidth(self.subtitleLabel.frame);
}

- (void)willMoveToWindow:(UIWindow *)newWindow
{
    [super willMoveToWindow:newWindow];
    
    // Ensure proper state when the view is reinserted
    [self updateSubscriptionStatus];
    
    if (newWindow) {
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(subscriptionStateDidChange:)
                                                   name:PushServiceSubscriptionStateDidChangeNotification
                                                 object:nil];
    }
    else {
        [NSNotificationCenter.defaultCenter removeObserver:self
                                                      name:PushServiceSubscriptionStateDidChangeNotification
                                                    object:nil];
    }
}

#pragma mark Getters and setters

- (void)setShow:(SRGShow *)show
{
    _show = show;
    
    self.titleLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleTitle];
    self.titleLabel.text = show.title;
    
    self.subtitleLabel.font = [UIFont srg_regularFontWithTextStyle:SRGAppearanceFontTextStyleBody];
    self.subtitleLabel.text = show.lead;
    
    [self.logoImageView play_requestImageForObject:show withScale:ImageScaleLarge type:SRGImageTypeDefault placeholder:ImagePlaceholderMediaList];
    
    [self updateSubscriptionStatus];
}

#pragma mark UI

- (void)updateSubscriptionStatus
{
    PushService *pushService = PushService.sharedService;
    if (! pushService) {
        self.subscriptionButton.hidden = YES;
        self.notificationButton.hidden = YES;
        return;
    }
    
    self.subscriptionButton.hidden = NO;
    self.notificationButton.hidden = NO;
    
    BOOL subscribed = [pushService isSubscribedToShow:self.show];
    [self.subscriptionButton setImage:subscribed ? [UIImage imageNamed:@"subscription_full-22"] : [UIImage imageNamed:@"subscription-22"]
                             forState:UIControlStateNormal];
    self.subscriptionButton.accessibilityLabel = subscribed ? PlaySRGAccessibilityLocalizedString(@"Unsubscribe from show", @"Show unsubscription label") : PlaySRGAccessibilityLocalizedString(@"Subscribe to show", @"Show subscription label");
    
    BOOL pushNotificationSubscribed = [pushService isPushNotificationSubscribedToShow:self.show];
    [self.notificationButton setImage:pushNotificationSubscribed ? [UIImage imageNamed:@"notification_full-22"] : [UIImage imageNamed:@"notification-22"]
                             forState:UIControlStateNormal];
    self.notificationButton.accessibilityLabel = pushNotificationSubscribed ? PlaySRGAccessibilityLocalizedString(@"Stop notifications from show", @"Show stop notification label") : PlaySRGAccessibilityLocalizedString(@"Be notified by the show", @"Show notification label");
}

- (void)updateAspectRatioWithSize:(CGSize)size
{
    BOOL isLandscape = (size.width > size.height);
    UITraitCollection *traitCollection = UIApplication.sharedApplication.keyWindow.traitCollection;
    if (traitCollection.verticalSizeClass == UIUserInterfaceSizeClassRegular
            && traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular
            && isLandscape) {
        self.logoImageViewRatio16_9Constraint.priority = LogoImageViewAspectRatioConstraintLowPriority;
        self.logoImageViewRatioBigLandscapeScreenConstraint.priority = LogoImageViewAspectRatioConstraintNormalPriority;
    }
    else {
        self.logoImageViewRatio16_9Constraint.priority = LogoImageViewAspectRatioConstraintNormalPriority;
        self.logoImageViewRatioBigLandscapeScreenConstraint.priority = LogoImageViewAspectRatioConstraintLowPriority;
    }
}

#pragma mark Actions

- (IBAction)toggleSubscription:(id)sender
{
    PushService *pushService = PushService.sharedService;
    if (! pushService) {
        return;
    }
    
    BOOL toggled = [pushService toggleSubscriptionForShow:self.show inView:self];
    if (! toggled) {
        return;
    }
    
    [self updateSubscriptionStatus];
    
    BOOL subscribed = [pushService isSubscribedToShow:self.show];
    
    // TODO: update analytics labels
    
    AnalyticsTitle analyticsTitle = (subscribed) ? AnalyticsTitleSubscriptionAdd : AnalyticsTitleSubscriptionRemove;
    SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
    labels.source = AnalyticsSourceButton;
    labels.value = self.show.URN;
    [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:analyticsTitle labels:labels];
    
    [Banner showSubscription:subscribed forShowWithName:self.show.title inView:self];
}

- (IBAction)toggleNotification:(id)sender
{
    PushService *pushService = PushService.sharedService;
    if (! pushService) {
        return;
    }
    
    BOOL toggled = [pushService togglePushNotificationForShow:self.show inView:self];
    if (! toggled) {
        return;
    }
    
    [self updateSubscriptionStatus];
    
    BOOL pushNotificationSubscribed = [pushService isPushNotificationSubscribedToShow:self.show];
    
    // TODO: update analytics labels
    
    AnalyticsTitle analyticsTitle = (pushNotificationSubscribed) ? AnalyticsTitleSubscriptionAdd : AnalyticsTitleSubscriptionRemove;
    SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
    labels.source = AnalyticsSourceButton;
    labels.value = self.show.URN;
    [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:analyticsTitle labels:labels];
    
    [Banner showPushNotificationSubscription:pushNotificationSubscribed forShowWithName:self.show.title inView:self];
}

#pragma mark Notifications

- (void)subscriptionStateDidChange:(NSNotification *)notification
{
    [self updateSubscriptionStatus];
}

@end
