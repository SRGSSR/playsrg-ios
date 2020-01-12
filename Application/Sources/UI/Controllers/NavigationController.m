//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "NavigationController.h"

#import "UIViewController+PlaySRG.h"

#import <CoconutKit/CoconutKit.h>
#import <SRGAppearance/SRGAppearance.h>

@interface NavigationController ()

@property (nonatomic) UIStatusBarStyle statusBarStyle;

@end

@implementation NavigationController

#pragma mark Object lifecycle

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController radioChannel:(RadioChannel *)radioChannel
{
    UIStatusBarStyle darkStatusBarStyle = UIStatusBarStyleDefault;
#ifdef __IPHONE_13_0
    if (@available(iOS 13, *)) {
        darkStatusBarStyle = UIStatusBarStyleDarkContent;
    }
#endif
    UIStatusBarStyle statusBarStyle = radioChannel.hasDarkStatusBar ? darkStatusBarStyle : UIStatusBarStyleLightContent;
    return [self initWithRootViewController:rootViewController tintColor:radioChannel.titleColor backgroundColor:radioChannel.color statusBarStyle:statusBarStyle];
}

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController
                                 tintColor:(UIColor *)tintColor
                           backgroundColor:(UIColor *)backgroundColor
                            statusBarStyle:(UIStatusBarStyle)statusBarStyle
{
    if (self = [super initWithRootViewController:rootViewController]) {
        self.statusBarStyle = statusBarStyle;
        self.autorotationMode = HLSAutorotationModeContainerAndTopChildren;
        
        UINavigationBar *navigationBar = self.navigationBar;
        navigationBar.barStyle = UIBarStyleBlack;
        
        // Apply background colors with a small shadow for better readability
        if (backgroundColor) {
            navigationBar.layer.shadowOpacity = 1.f;
            
            navigationBar.barTintColor = backgroundColor;
            navigationBar.translucent = NO;
        }
        // Use standard blur with no shadow (which would break the blur).
        else {
            navigationBar.layer.shadowOpacity = 0.f;
            
            navigationBar.barTintColor = nil;
            navigationBar.translucent = YES;
        }
        
        UIColor *foregroundColor = tintColor ?: UIColor.whiteColor;
        navigationBar.tintColor = foregroundColor;
        navigationBar.titleTextAttributes = @{ NSFontAttributeName : [UIFont srg_mediumFontWithSize:18.f],
                                               NSForegroundColorAttributeName : foregroundColor };
        
        for (NSNumber *controlState in @[ @(UIControlStateNormal), @(UIControlStateHighlighted), @(UIControlStateDisabled) ]) {
            [[UIBarButtonItem appearanceWhenContainedInInstancesOfClasses:@[self.class]] setTitleTextAttributes:@{ NSFontAttributeName : [UIFont srg_regularFontWithSize:16.f],
                                                                                                                   NSForegroundColorAttributeName : foregroundColor }
                                                                                                       forState:controlState.integerValue];
        }
    }
    return self;
}

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController
{
    return [self initWithRootViewController:rootViewController tintColor:nil backgroundColor:nil statusBarStyle:UIStatusBarStyleLightContent];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

- (instancetype)initWithNavigationBarClass:(Class)navigationBarClass toolbarClass:(Class)toolbarClass
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

#pragma clang diagnostic pop

#pragma mark Status bar

- (BOOL)prefersStatusBarHidden
{
    return [self.topViewController prefersStatusBarHidden];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return self.statusBarStyle;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation
{
    return [self.topViewController preferredStatusBarUpdateAnimation];
}

#pragma mark Accessibility

- (BOOL)accessibilityPerformEscape
{
    if (self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
        return YES;
    }
    else if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
        return YES;
    }
    else {
        return NO;
    }
}

#pragma mark PlayApplicationNavigation protocol

- (NSArray<NSNumber *> *)supportedApplicationSections
{
    if (self.viewControllers[0] && [self.viewControllers[0] conformsToProtocol:@protocol(PlayApplicationNavigation)]) {
        return ((UIViewController<PlayApplicationNavigation> *)self.viewControllers[0]).supportedApplicationSections;
    }
    else {
        return @[];
    }
}

- (void)openApplicationSectionInfo:(ApplicationSectionInfo *)applicationSectionInfo
{
    [self popToRootViewControllerAnimated:NO];
    
    if (self.viewControllers[0] && [self.viewControllers[0] conformsToProtocol:@protocol(PlayApplicationNavigation)]) {
        [((UIViewController<PlayApplicationNavigation> *)self.viewControllers[0]) openApplicationSectionInfo:applicationSectionInfo];
    }
}

@end
