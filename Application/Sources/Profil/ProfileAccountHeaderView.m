//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "ProfileAccountHeaderView.h"

#import "ApplicationSettings.h"
#import "AnalyticsConstants.h"
#import "History.h"
#import "NavigationController.h"
#import "NSBundle+PlaySRG.h"
#import "UIColor+PlaySRG.h"
#import "UIWindow+PlaySRG.h"
#import "WebViewController.h"

#import <libextobjc/libextobjc.h>
#import <SRGAppearance/SRGAppearance.h>
#import <SRGAnalytics/SRGAnalytics.h>
#import <SRGIdentity/SRGIdentity.h>
#import <SRGUserData/SRGUserData.h>
#import <YYWebImage/YYWebImage.h>

@interface ProfileAccountHeaderView ()

@property (nonatomic, weak) IBOutlet UIImageView *avatarImageView;
@property (nonatomic, weak) IBOutlet UILabel *accountLabel;

@end

@implementation ProfileAccountHeaderView

#pragma mark Overrides

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    UITapGestureRecognizer *gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(manageAccount:)];
    [self addGestureRecognizer:gestureRecognizer];
}

- (void)willMoveToWindow:(UIWindow *)newWindow
{
    [super willMoveToWindow:newWindow];
    
    if (newWindow) {
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(didUpdateAccount:)
                                                   name:SRGIdentityServiceDidUpdateAccountNotification
                                                 object:SRGIdentityService.currentIdentityService];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(contentSizeCategoryDidChange:)
                                                   name:UIContentSizeCategoryDidChangeNotification
                                                 object:nil];
        [self reloadData];
    }
    else {
        [NSNotificationCenter.defaultCenter removeObserver:self
                                                      name:SRGIdentityServiceDidUpdateAccountNotification
                                                    object:SRGIdentityService.currentIdentityService];
        [NSNotificationCenter.defaultCenter removeObserver:self
                                                      name:UIContentSizeCategoryDidChangeNotification
                                                    object:nil];
        
        [self.avatarImageView yy_cancelCurrentImageRequest];
    }
}

#pragma mark Accessibility

- (BOOL)isAccessibilityElement
{
    return YES;
}

- (UIAccessibilityTraits)accessibilityTraits
{
    return UIAccessibilityTraitButton;
}

- (NSString *)accessibilityLabel
{
    SRGIdentityService *identityService = SRGIdentityService.currentIdentityService;
    if (identityService.loggedIn) {
        NSString *accountDescription = identityService.account.displayName ?: identityService.emailAddress;
        if (accountDescription) {
            return [NSString stringWithFormat:PlaySRGAccessibilityLocalizedString(@"Logged in user: %@", @"Accessibility introductory text for the logged in user"), accountDescription];
        }
        else {
            return PlaySRGAccessibilityLocalizedString(@"My account", @"Text displayed when a user is logged in but no information has been retrieved yet");
        }
    }
    else {
        return PlaySRGAccessibilityLocalizedString(@"Login or sign up", @"Accessibility text for the login / signup header");
    }
}

- (NSString *)accessibilityHint
{
    SRGIdentityService *identityService = SRGIdentityService.currentIdentityService;
    if (identityService.loggedIn) {
        return PlaySRGAccessibilityLocalizedString(@"Manages account information", @"Accessibility hint associated with the account header");
    }
    else {
        return nil;
    }
}

#pragma mark Data

- (void)reloadData
{
    static const CGFloat kImageSize = 300.f;
    
    SRGIdentityService *identityService = SRGIdentityService.currentIdentityService;
    UIColor *color = identityService.loggedIn ? UIColor.whiteColor : UIColor.play_grayColor;
    NSString *placeholderImageName = identityService.loggedIn ? @"account_logged_in_icon-56" : @"account_logged_out_icon-56";
    UIImage *placeholderImage = [[UIImage imageNamed:placeholderImageName] srg_imageTintedWithColor:color];
    
    NSString *emailAddress = identityService.emailAddress;
    if (emailAddress) {
        NSString *gravatarImageURLString = [NSString stringWithFormat:@"https://www.gravatar.com/avatar/%@?d=404&s=%@", emailAddress.lowercaseString.md5hash, @(kImageSize)];
        NSURL *gravatarImageURL = [NSURL URLWithString:gravatarImageURLString];
        YYWebImageManager *webImageManager = YYWebImageManager.sharedManager;
        UIImage *cachedImage = [webImageManager.cache getImageForKey:[webImageManager cacheKeyForURL:gravatarImageURL]];
        [self.avatarImageView yy_setImageWithURL:gravatarImageURL placeholder:cachedImage ?: placeholderImage options:YYWebImageOptionSetImageWithFadeAnimation progress:nil transform:^UIImage * _Nullable(UIImage * _Nonnull image, NSURL * _Nonnull url) {
            // Use image size as corner radius (larger than half image size) so that the image is rounded to a circle
            return [image yy_imageByRoundCornerRadius:kImageSize borderWidth:3.f borderColor:color];
        } completion:nil];
    }
    else {
        [self.avatarImageView yy_setImageWithURL:nil placeholder:placeholderImage options:YYWebImageOptionSetImageWithFadeAnimation completion:nil];
    }
    
    self.accountLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleSubtitle];
    self.accountLabel.textColor = color;
    
    if (identityService.loggedIn) {
        self.accountLabel.text = identityService.account.displayName ?: emailAddress ?: NSLocalizedString(@"My account", @"Text displayed when a user is logged in but no information has been retrieved yet");
    }
    else {
        self.accountLabel.text = NSLocalizedString(@"Login / Sign up", @"Text displayed within the login / sign up menu header when no user is displayed");
    }
}

#pragma mark Actions

- (void)manageAccount:(id)sender
{
    SRGIdentityService *identityService = SRGIdentityService.currentIdentityService;
    if (identityService.loggedIn) {
        [identityService showAccountView];
    }
    else if ([identityService loginWithEmailAddress:[NSUserDefaults.standardUserDefaults stringForKey:PlaySRGSettingLastLoggedInEmailAddress]]) {
        SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
        labels.type = AnalyticsTypeActionDisplayLogin;
        [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleIdentity labels:labels];
    }
}

#pragma mark Notifications

- (void)didUpdateAccount:(NSNotification *)notification
{
    [self reloadData];
}

- (void)contentSizeCategoryDidChange:(NSNotification *)notification
{
    [self reloadData];
}

@end
