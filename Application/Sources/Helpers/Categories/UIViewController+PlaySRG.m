//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UIViewController+PlaySRG.h"

#import "AnalyticsConstants.h"
#import "ApplicationSettings.h"
#import "Banner.h"
#import "GoogleCast.h"
#import "History.h"
#import "MediaPlayerViewController.h"
#import "PlayErrors.h"
#import "Playlist.h"
#import "Previewing.h"
#import "PreviewingDelegate.h"
#import "UIDevice+PlaySRG.h"
#import "UIWindow+PlaySRG.h"

#import <objc/runtime.h>

@import GoogleCast;
@import libextobjc;
@import SRGDataProviderNetwork;

// We retain the presentation delegates with the view controller. If not unregistered, UIKit cleans them up when the
// view controller is deallocated anyway. We must retain the delegates, otherwise they will get deallocated early
static void *s_previewingDelegatesKey = &s_previewingDelegatesKey;
static void *s_longPressGestureRecognizerKey = &s_longPressGestureRecognizerKey;
static void *s_previewingContextKey = &s_previewingContextKey;
static void *s_isViewVisibleKey = &s_isViewVisibleKey;

@implementation UIViewController (PlaySRG)

#pragma mark Class methods

+ (void)load
{
    method_exchangeImplementations(class_getInstanceMethod(self, @selector(viewWillAppear:)),
                                   class_getInstanceMethod(self, @selector(UIViewController_PlaySRG_swizzled_viewWillAppear:)));
    method_exchangeImplementations(class_getInstanceMethod(self, @selector(viewDidDisappear:)),
                                   class_getInstanceMethod(self, @selector(UIViewController_PlaySRG_swizzled_viewDidDisappear:)));
    method_exchangeImplementations(class_getInstanceMethod(self, @selector(registerForPreviewingWithDelegate:sourceView:)),
                                   class_getInstanceMethod(self, @selector(UIViewController_PlaySRG_swizzled_registerForPreviewingWithDelegate:sourceView:)));
}

+ (UIInterfaceOrientationMask)play_supportedInterfaceOrientations
{
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskPortrait;
    }
    else {
        return UIInterfaceOrientationMaskAll;
    }
}

#pragma mark Swizzled methods

// Only swizzle registration method. Unregistration is automatic, and associated objects are automatically cleaned up when the
// object they are associated to is deallocated
- (id<UIViewControllerPreviewing>)UIViewController_PlaySRG_swizzled_registerForPreviewingWithDelegate:(id<UIViewControllerPreviewingDelegate>)delegate sourceView:(UIView *)sourceView
{
    if ([delegate conformsToProtocol:@protocol(PreviewingDelegate)]) {
        NSMutableSet<PreviewingDelegate *> *previewingDelegates = objc_getAssociatedObject(self, s_previewingDelegatesKey);
        if (! previewingDelegates) {
            previewingDelegates = [NSMutableSet set];
            objc_setAssociatedObject(self, s_previewingDelegatesKey, previewingDelegates, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        
        PreviewingDelegate *previewingDelegate = [[PreviewingDelegate alloc] initWithRealDelegate:(id<PreviewingDelegate>)delegate];
        [previewingDelegates addObject:previewingDelegate];
        
        id<UIViewControllerPreviewing> previewingViewController = nil;
        
        // Register for 3D Touch support if available
        // Warning: FLEX lies about 3D touch support. When running the app in the simulator with FLEX linked, the following
        //          condition is always true
        if (self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable) {
            previewingViewController = [self UIViewController_PlaySRG_swizzled_registerForPreviewingWithDelegate:previewingDelegate sourceView:sourceView];
        }

        UIGestureRecognizer *longPressGestureRecognizer = [objc_getAssociatedObject(sourceView, s_longPressGestureRecognizerKey) nonretainedObjectValue];
        if (longPressGestureRecognizer) {
            [sourceView removeGestureRecognizer:longPressGestureRecognizer];
        }
        
        longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:previewingDelegate action:@selector(handleLongPress:)];
        [sourceView addGestureRecognizer:longPressGestureRecognizer];
        objc_setAssociatedObject(sourceView, s_longPressGestureRecognizerKey, [NSValue valueWithNonretainedObject:longPressGestureRecognizer], OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        return previewingViewController;
    }
    else {
        return [self UIViewController_PlaySRG_swizzled_registerForPreviewingWithDelegate:delegate sourceView:sourceView];
    }
}

- (void)UIViewController_PlaySRG_swizzled_viewWillAppear:(BOOL)animated
{
    [self UIViewController_PlaySRG_swizzled_viewWillAppear:animated];
    
    [self play_setViewVisible:YES];
}

- (void)UIViewController_PlaySRG_swizzled_viewDidDisappear:(BOOL)animated
{
    [self UIViewController_PlaySRG_swizzled_viewDidDisappear:animated];
    
    [self play_setViewVisible:NO];
}

#pragma mark Getters and setters

- (BOOL)play_isMovingToParentViewController
{
    id<UIViewControllerTransitionCoordinator> transitionCoordinator = self.transitionCoordinator;
    if (transitionCoordinator.cancelled) {
        return NO;
    }
    
    if (self.movingToParentViewController || self.beingPresented) {
        return YES;
    }
    
    // Page view controllers are buggy and do not consider the child to be moving to the controller when appearing. The check is not
    // valid outside view controller's view lifecycle methods
    if ([self.parentViewController isKindOfClass:UIPageViewController.class]) {
        return YES;
    }
    
    UIViewController *parentViewController = self.parentViewController;
    while (parentViewController) {
        if ([parentViewController play_isMovingFromParentViewController]) {
            return YES;
        }
        parentViewController = parentViewController.parentViewController;
    }
    
    return NO;
}

- (BOOL)play_isMovingFromParentViewController
{
    if (self.movingFromParentViewController || self.beingDismissed) {
        return YES;
    }
    
    // See comment above. The parent view controller for a page view controller is still the controller, even in -viewDidDisappear:
    if ([self.parentViewController isKindOfClass:UIPageViewController.class]) {
        return YES;
    }
    
    UIViewController *parentViewController = self.parentViewController;
    while (parentViewController) {
        if ([parentViewController play_isMovingFromParentViewController]) {
            return YES;
        }
        parentViewController = parentViewController.parentViewController;
    }
    
    return NO;
}

- (BOOL)play_isViewVisible
{
    return [objc_getAssociatedObject(self, s_isViewVisibleKey) boolValue];
}

- (void)play_setViewVisible:(BOOL)visible
{
    objc_setAssociatedObject(self, s_isViewVisibleKey, @(visible), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIViewController *)play_topViewController
{
    UIViewController *topViewController = self;
    while (topViewController.presentedViewController) {
        topViewController = topViewController.presentedViewController;
    }
    return topViewController;
}

#pragma mark Previewing

- (void)setPlay_previewingContext:(id<UIViewControllerPreviewing>)previewingContext
{
    objc_setAssociatedObject(self, s_previewingContextKey, previewingContext, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id<UIViewControllerPreviewing>)play_previewingContext
{
    return objc_getAssociatedObject(self, s_previewingContextKey);
}

#pragma mark Media player presentation

- (void)play_presentMediaPlayerWithMedia:(SRGMedia *)media position:(SRGPosition *)position airPlaySuggestions:(BOOL)airPlaySuggestions fromPushNotification:(BOOL)fromPushNotification animated:(BOOL)animated completion:(void (^)(PlayerType))completion
{
    if (! position) {
        position = HistoryResumePlaybackPositionForMedia(media);
    }
    GCKCastSession *castSession = [GCKCastContext sharedInstance].sessionManager.currentCastSession;
    if (castSession) {
        [self play_presentGoogleCastPlayerWithMedia:media standalone:YES position:position airPlaySuggestions:airPlaySuggestions fromPushNotification:fromPushNotification animated:animated completion:completion];
    }
    else {
        [self play_presentNativeMediaPlayerWithMedia:media position:position airPlaySuggestions:airPlaySuggestions fromPushNotification:fromPushNotification animated:animated completion:^{
            completion ? completion(PlayerTypeNative) : nil;
        }];
    }
}

- (void)play_presentMediaPlayerFromLetterboxController:(SRGLetterboxController *)letterboxController withAirPlaySuggestions:(BOOL)airPlaySuggestions fromPushNotification:(BOOL)fromPushNotification animated:(BOOL)animated completion:(void (^)(PlayerType))completion
{
    GCKCastSession *castSession = [GCKCastContext sharedInstance].sessionManager.currentCastSession;
    if (castSession) {
        [self play_presentGoogleCastPlayerFromLetterboxController:letterboxController withAirPlaySuggestions:airPlaySuggestions fromPushNotification:fromPushNotification animated:animated completion:completion];
    }
    else {
        [self play_presentNativeMediaPlayerFromLetterboxController:letterboxController withAirPlaySuggestions:airPlaySuggestions fromPushNotification:fromPushNotification animated:animated completion:^{
            completion ? completion(PlayerTypeNative) : nil;
        }];
    }
}

#pragma mark Implementation helpers

- (void)play_presentNativeMediaPlayerWithMedia:(SRGMedia *)media position:(SRGPosition *)position airPlaySuggestions:(BOOL)airPlaySuggestions fromPushNotification:(BOOL)fromPushNotification animated:(BOOL)animated completion:(void (^)(void))completion
{
    UIViewController *topViewController = UIApplication.sharedApplication.keyWindow.play_topViewController;
    if ([topViewController isKindOfClass:MediaPlayerViewController.class]) {
        MediaPlayerViewController *mediaPlayerViewController = (MediaPlayerViewController *)topViewController;
        SRGLetterboxController *letterboxController = mediaPlayerViewController.letterboxController;
        Playlist *playlist = PlaylistForURN(media.URN);
        letterboxController.playlistDataSource = playlist;
        letterboxController.playbackTransitionDelegate = playlist;
        
        if ([letterboxController.media isEqual:media] && letterboxController.playbackState != SRGMediaPlayerPlaybackStateIdle
                && letterboxController.playbackState != SRGMediaPlayerPlaybackStatePreparing
                && letterboxController.playbackState != SRGMediaPlayerPlaybackStateEnded) {
            [letterboxController seekToPosition:position withCompletionHandler:^(BOOL finished) {
                [letterboxController play];
            }];
        }
        else {
            [letterboxController playMedia:media atPosition:position withPreferredSettings:ApplicationSettingPlaybackSettings()];
        }
        completion ? completion() : nil;
    }
    else {
        void (^openPlayer)(void) = ^{
            MediaPlayerViewController *mediaPlayerViewController = [[MediaPlayerViewController alloc] initWithMedia:media position:position fromPushNotification:fromPushNotification];
            SRGLetterboxController *letterboxController = mediaPlayerViewController.letterboxController;
            Playlist *playlist = PlaylistForURN(media.URN);
            letterboxController.playlistDataSource = playlist;
            letterboxController.playbackTransitionDelegate = playlist;
            [topViewController presentViewController:mediaPlayerViewController animated:animated completion:completion];
        };
        
        if (@available(iOS 13, *)) {
            if (airPlaySuggestions) {
                [AVAudioSession.sharedInstance prepareRouteSelectionForPlaybackWithCompletionHandler:^(BOOL shouldStartPlayback, AVAudioSessionRouteSelection routeSelection) {
                    if (shouldStartPlayback && routeSelection != AVAudioSessionRouteSelectionNone) {
                        openPlayer();
                    }
                }];
            }
            else {
                openPlayer();
            }
        }
        else {
            openPlayer();
        }
    }
}

- (void)play_presentNativeMediaPlayerFromLetterboxController:(SRGLetterboxController *)letterboxController withAirPlaySuggestions:(BOOL)airPlaySuggestions fromPushNotification:(BOOL)fromPushNotification animated:(BOOL)animated completion:(void (^)(void))completion
{
    UIViewController *topViewController = UIApplication.sharedApplication.keyWindow.play_topViewController;
    if ([topViewController isKindOfClass:MediaPlayerViewController.class]) {
        MediaPlayerViewController *mediaPlayerViewController = (MediaPlayerViewController *)topViewController;
        if (mediaPlayerViewController.letterboxController == letterboxController) {
            completion ? completion() : nil;
            return;
        }
    }
    
    void (^openPlayer)(void) = ^{
        MediaPlayerViewController *mediaPlayerViewController = [[MediaPlayerViewController alloc] initWithController:letterboxController position:nil fromPushNotification:fromPushNotification];
        Playlist *playlist = PlaylistForURN(letterboxController.URN);
        letterboxController.playlistDataSource = playlist;
        letterboxController.playbackTransitionDelegate = playlist;
        [topViewController presentViewController:mediaPlayerViewController animated:animated completion:completion];
    };
    
    if (@available(iOS 13, *)) {
        if (airPlaySuggestions) {
            [AVAudioSession.sharedInstance prepareRouteSelectionForPlaybackWithCompletionHandler:^(BOOL shouldStartPlayback, AVAudioSessionRouteSelection routeSelection) {
                if (shouldStartPlayback && routeSelection != AVAudioSessionRouteSelectionNone) {
                    openPlayer();
                }
            }];
        }
        else {
            openPlayer();
        }
    }
    else {
        openPlayer();
    }
}

// The completion block returns cast errors only. To know whether playback could correctly start, check the started boolean
- (void)play_prepareGoogleCastPlaybackWithMediaComposition:(SRGMediaComposition *)mediaComposition position:(SRGPosition *)position completion:(void (^)(BOOL started, NSError * _Nullable error))completion
{
    if (! mediaComposition) {
        completion ? completion(NO, nil) : nil;
        return;
    }
    
    NSError *error = nil;
    BOOL success = GoogleCastPlayMediaComposition(mediaComposition, position, &error);
    completion ? completion(success, error) : nil;
}

- (void)play_presentGoogleCastControlsAnimated:(BOOL)animated completion:(void (^)(void))completion
{
    UIViewController *topViewController = UIApplication.sharedApplication.keyWindow.play_topViewController;
    if ([topViewController isKindOfClass:GCKUIExpandedMediaControlsViewController.class]) {
        completion ? completion() : nil;
        return;
    }
    
    void (^presentGoogleCastControls)(void) = ^{
        GCKUIExpandedMediaControlsViewController *mediaControlsViewController = [GCKCastContext sharedInstance].defaultExpandedMediaControlsViewController;
        mediaControlsViewController.modalPresentationStyle = UIModalPresentationFullScreen;
        mediaControlsViewController.hideStreamPositionControlsForLiveContent = YES;
        
        // The top view controller might have changed if dismissal occurred
        UIViewController *topViewController = UIApplication.sharedApplication.keyWindow.play_topViewController;
        [topViewController presentViewController:mediaControlsViewController animated:animated completion:completion];
        
        [SRGAnalyticsTracker.sharedTracker trackPageViewWithTitle:AnalyticsPageTitlePlayer levels:@[ AnalyticsPageLevelPlay, AnalyticsPageLevelGoogleCast ]];
    };
    
    if ([topViewController isKindOfClass:MediaPlayerViewController.class]) {
        [topViewController dismissViewControllerAnimated:YES completion:presentGoogleCastControls];
    }
    else {
        presentGoogleCastControls();
    }
}

- (void)play_presentGoogleCastPlayerWithMedia:(SRGMedia *)media standalone:(BOOL)standalone position:(SRGPosition *)position airPlaySuggestions:(BOOL)airPlaySuggestions fromPushNotification:(BOOL)fromPushNotification animated:(BOOL)animated completion:(void (^)(PlayerType))completion
{
    [[SRGDataProvider.currentDataProvider mediaCompositionForURN:media.URN standalone:standalone withCompletionBlock:^(SRGMediaComposition * _Nullable mediaComposition, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        void (^presentNativePlayer)(NSString *) = ^(NSString *message) {
            [self play_presentNativeMediaPlayerWithMedia:media position:position airPlaySuggestions:airPlaySuggestions fromPushNotification:fromPushNotification animated:animated completion:^{
                [Banner showWithStyle:BannerStyleInfo message:message image:nil sticky:NO inViewController:nil /* self is being covered */];
                completion ? completion(PlayerTypeNative) : nil;
            }];
        };
        
        if (error) {
            presentNativePlayer(nil);
            return;
        }
        
        [self play_prepareGoogleCastPlaybackWithMediaComposition:mediaComposition position:position completion:^(BOOL started, NSError * _Nullable error) {
            if (started) {
                [self play_presentGoogleCastControlsAnimated:animated completion:^{
                    completion ? completion(PlayerTypeGoogleCast) : nil;
                }];
            }
            else {
                presentNativePlayer(error.localizedDescription);
            }
        }];
    }] resume];
}

- (void)play_presentGoogleCastPlayerFromLetterboxController:(SRGLetterboxController *)letterboxController withAirPlaySuggestions:(BOOL)airPlaySuggestions fromPushNotification:(BOOL)fromPushNotification animated:(BOOL)animated completion:(void (^)(PlayerType))completion
{
    SRGPosition *position = [SRGPosition positionAtTime:letterboxController.currentTime];
    [self play_prepareGoogleCastPlaybackWithMediaComposition:letterboxController.mediaComposition position:position completion:^(BOOL started, NSError * _Nullable error) {
        if (started) {
            [self play_presentGoogleCastControlsAnimated:animated completion:^{
                completion ? completion(PlayerTypeGoogleCast) : nil;
            }];
        }
        else {
            [self play_presentNativeMediaPlayerFromLetterboxController:letterboxController withAirPlaySuggestions:airPlaySuggestions fromPushNotification:fromPushNotification animated:animated completion:^{
                [Banner showWithStyle:BannerStyleInfo message:error.localizedDescription image:nil sticky:NO inViewController:nil /* self is being covered */];
                completion ? completion(PlayerTypeNative) : nil;
            }];
        }
    }];
}

- (BOOL)play_supportsOrientation:(UIInterfaceOrientation)orientation
{
    return (self.supportedInterfaceOrientations & (1 << orientation)) != 0;
}

- (void)play_dismissViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion
{
    UIViewController *topViewController = self.play_topViewController;
    
    // See https://stackoverflow.com/a/29560217
    UIViewController *presentingViewController = topViewController.presentingViewController;
    if (! [presentingViewController play_supportsOrientation:(UIInterfaceOrientation)UIDevice.currentDevice.orientation]) {
        if ([presentingViewController play_supportsOrientation:UIInterfaceOrientationPortrait]) {
            [UIDevice.currentDevice setValue:@(UIDeviceOrientationPortrait) forKey:@keypath(UIDevice.new, orientation)];
        }
        else if ([presentingViewController play_supportsOrientation:UIInterfaceOrientationPortraitUpsideDown]) {
            [UIDevice.currentDevice setValue:@(UIDeviceOrientationPortraitUpsideDown) forKey:@keypath(UIDevice.new, orientation)];
        }
        else if ([presentingViewController play_supportsOrientation:UIInterfaceOrientationLandscapeLeft]) {
            [UIDevice.currentDevice setValue:@(UIDeviceOrientationLandscapeLeft) forKey:@keypath(UIDevice.new, orientation)];
        }
        else if ([presentingViewController play_supportsOrientation:UIInterfaceOrientationLandscapeRight]) {
            [UIDevice.currentDevice setValue:@(UIDeviceOrientationLandscapeRight) forKey:@keypath(UIDevice.new, orientation)];
        }
    }
    [self dismissViewControllerAnimated:animated completion:completion];
}

@end
