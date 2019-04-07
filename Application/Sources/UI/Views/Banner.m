//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "Banner.h"

#import "NSBundle+PlaySRG.h"
#import "Play-Swift-Bridge.h"
#import "UIColor+PlaySRG.h"

#import <CoconutKit/CoconutKit.h>
#import <SRGAppearance/SRGAppearance.h>
#import <SRGDataProvider/SRGDataProvider.h>

static NSString *BannerShortenedName(NSString *name);

@implementation Banner

#pragma mark Class methods

+ (void)showWithStyle:(BannerStyle)style message:(NSString *)message image:(UIImage *)image sticky:(BOOL)sticky inView:(UIView *)view
{
    [self showWithStyle:style message:message image:image sticky:sticky inViewController:view.nearestViewController];
}

+ (void)showWithStyle:(BannerStyle)style message:(NSString *)message image:(UIImage *)image sticky:(BOOL)sticky inViewController:(UIViewController *)viewController
{
    if (! message) {
        return;
    }
    
    NSString *accessibilityPrefix = nil;
    UIColor *backgroundColor = nil;
    UIColor *foregroundColor = nil;
    
    switch (style) {
        case BannerStyleInfo: {
            accessibilityPrefix = PlaySRGAccessibilityLocalizedString(@"Information", @"Introductory title for information notifications");
            backgroundColor = [UIColor srg_blueColor];
            foregroundColor = UIColor.whiteColor;
            break;
        }
            
        case BannerStyleWarning: {
            accessibilityPrefix = PlaySRGAccessibilityLocalizedString(@"Warning", @"Introductory title for warning notifications");
            backgroundColor = UIColor.orangeColor;
            foregroundColor = UIColor.blackColor;
            break;
        }
            
        case BannerStyleError: {
            accessibilityPrefix = PlaySRGAccessibilityLocalizedString(@"Error", @"Introductory title for error notifications");
            backgroundColor = UIColor.play_redColor;
            foregroundColor = UIColor.whiteColor;
            break;
        }
    }
    
    [SwiftMessagesBridge show:message accessibilityPrefix:accessibilityPrefix image:image viewController:viewController backgroundColor:backgroundColor foregroundColor:foregroundColor sticky:sticky];
}

@end

@implementation Banner (Convenience)

+ (void)showError:(NSError *)error inView:(UIView *)view
{
    [self showError:error inViewController:view.nearestViewController];
}

+ (void)showError:(NSError *)error inViewController:(UIViewController *)viewController
{
    if (! error) {
        return;
    }
    
    // Multiple errors. Pick the first ones
    if ([error hasCode:SRGNetworkErrorMultiple withinDomain:SRGNetworkErrorDomain]) {
        error = [error.userInfo[SRGNetworkErrorsKey] firstObject];
    }
    
    // Never display cancellation errors
    if ([error hasCode:NSURLErrorCancelled withinDomain:NSURLErrorDomain]) {
        return;
    }
    
    [self showWithStyle:BannerStyleError message:error.localizedDescription image:nil sticky:NO inViewController:viewController];
}

+ (void)showFavorite:(BOOL)isFavorite forItemWithName:(NSString *)name inView:(UIView *)view
{
    [self showFavorite:isFavorite forItemWithName:name inViewController:view.nearestViewController];
}

+ (void)showFavorite:(BOOL)isFavorite forItemWithName:(NSString *)name inViewController:(UIViewController *)viewController
{
    if (! name) {
        name = NSLocalizedString(@"The selected content", @"Name of the favorited item, if no title or name to display");
    }
    
    NSString *messageFormatString = isFavorite ? NSLocalizedString(@"%@ has been added to favorites", @"Message displayed at the top of the screen when adding a media or a show to the favorite list. Quotes are managed by the application.") : NSLocalizedString(@"%@ has been removed from favorites", @"Message displayed at the top of the screen when removing an item from the favorite list. Quotes are managed by the application.");
    NSString *message = [NSString stringWithFormat:messageFormatString, BannerShortenedName(name)];
    UIImage *image = isFavorite ? [UIImage imageNamed:@"favorite_full-22"] : [UIImage imageNamed:@"favorite-22"];
    [self showWithStyle:BannerStyleInfo message:message image:image sticky:NO inViewController:viewController];
}

+ (void)showSubscription:(BOOL)subscribed forShowWithName:(NSString *)name inView:(UIView *)view
{
    [self showSubscription:subscribed forShowWithName:name inViewController:view.nearestViewController];
}

+ (void)showSubscription:(BOOL)subscribed forShowWithName:(NSString *)name inViewController:(UIViewController *)viewController
{
    if (! name) {
        name = NSLocalizedString(@"The selected content", @"Name of the subscription item, if no title or name to display");
    }
    
    NSString *messageFormatString = subscribed ? NSLocalizedString(@"%@ has been added to subscriptions", @"Message displayed at the top of the screen when adding an item to the subscription list. Quotes are managed by the application.") : NSLocalizedString(@"%@ has been removed from subscriptions", @"Message at the top of the screen displayed when removing an item from the subscription list. Quotes are managed by the application.");
    NSString *message = [NSString stringWithFormat:messageFormatString, BannerShortenedName(name)];
    UIImage *image = subscribed ? [UIImage imageNamed:@"subscription_full-22"] : [UIImage imageNamed:@"subscription-22"];
    [self showWithStyle:BannerStyleInfo message:message image:image sticky:NO inViewController:viewController];
}

+ (void)showPushNotificationSubscription:(BOOL)subscribed forShowWithName:(NSString *)name inView:(UIView *)view
{
    [self showPushNotificationSubscription:subscribed forShowWithName:name inViewController:view.nearestViewController];
}

+ (void)showPushNotificationSubscription:(BOOL)subscribed forShowWithName:(NSString *)name inViewController:(UIViewController *)viewController
{
    if (! name) {
        name = NSLocalizedString(@"The selected content", @"Name of the subscription item, if no title or name to display");
    }
    
    NSString *messageFormatString = subscribed ? NSLocalizedString(@"%@ will notified you.", @"Message displayed at the top of the screen when adding an item to the notification list. Quotes are managed by the application.") : NSLocalizedString(@"%@ won't notify you anymore.", @"Message at the top of the screen displayed when removing an item from the notification list. Quotes are managed by the application.");
    NSString *message = [NSString stringWithFormat:messageFormatString, BannerShortenedName(name)];
    UIImage *image = subscribed ? [UIImage imageNamed:@"notification_full-22"] : [UIImage imageNamed:@"notification-22"];
    [self showWithStyle:BannerStyleInfo message:message image:image sticky:NO inViewController:viewController];
}

+ (void)showWatchLaterAdded:(BOOL)added forItemWithName:(NSString *)name inView:(UIView *)view
{
    [self showWatchLaterAdded:added forItemWithName:name inViewController:view.nearestViewController];
}

+ (void)showWatchLaterAdded:(BOOL)added forItemWithName:(NSString *)name inViewController:(UIViewController *)viewController
{
    if (! name) {
        name = NSLocalizedString(@"The selected content", @"Name of the watch later item, if no title or name to display");
    }
    
    NSString *messageFormatString = added ? NSLocalizedString(@"%@ has been added to \"Watch later\" list", @"Message displayed at the top of the screen when adding a media to the watch later list. Quotes are managed by the application.") : NSLocalizedString(@"%@ has been removed from \"Watch later\" list", @"Message displayed at the top of the screen when removing an item from the watch later list. Quotes are managed by the application.");
    NSString *message = [NSString stringWithFormat:messageFormatString, BannerShortenedName(name)];
    UIImage *image = added ? [UIImage imageNamed:@"watch_later_full-22"] : [UIImage imageNamed:@"watch_later-22"];
    [self showWithStyle:BannerStyleInfo message:message image:image sticky:NO inViewController:viewController];
}

@end

static NSString *BannerShortenedName(NSString *name)
{
    if (name) {
        static const NSUInteger kMaxTitleLength = 60;
        
        if (name.length > kMaxTitleLength) {
            name = [[name substringWithRange:NSMakeRange(0, kMaxTitleLength)] stringByAppendingString:@"…"];
        }
        return [NSString stringWithFormat:@"\"%@\"", name];
    }
    else {
        return nil;
    }
}
