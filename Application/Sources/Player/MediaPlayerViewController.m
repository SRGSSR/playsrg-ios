//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "MediaPlayerViewController.h"

#import "ActivityItemSource.h"
#import "ApplicationSettings.h"
#import "AnalyticsConstants.h"
#import "ApplicationConfiguration.h"
#import "Banner.h"
#import "Download.h"
#import "GoogleCast.h"
#import "History.h"
#import "LiveAccessView.h"
#import "ModalTransition.h"
#import "NSBundle+PlaySRG.h"
#import "NSDateFormatter+PlaySRG.h"
#import "NSString+PlaySRG.h"
#import "NSTimer+PlaySRG.h"
#import "PlayAppDelegate.h"
#import "PlayApplication.h"
#import "PlayDateComponentsFormatter.h"
#import "PlayErrors.h"
#import "Playlist.h"
#import "PushService.h"
#import "RelatedContentView.h"
#import "SRGDataProvider+PlaySRG.h"
#import "SRGMedia+PlaySRG.h"
#import "SRGMediaComposition+PlaySRG.h"
#import "SRGProgram+PlaySRG.h"
#import "StoreReview.h"
#import "UIColor+PlaySRG.h"
#import "UIDevice+PlaySRG.h"
#import "UIImage+PlaySRG.h"
#import "UIImageView+PlaySRG.h"
#import "UILabel+PlaySRG.h"
#import "UIStackView+PlaySRG.h"
#import "UIView+PlaySRG.h"
#import "UIViewController+PlaySRG.h"
#import "UIWindow+PlaySRG.h"
#import "WatchLater.h"

#import <FXReachability/FXReachability.h>
#import <GoogleCast/GoogleCast.h>
#import <libextobjc/libextobjc.h>
#import <MAKVONotificationCenter/MAKVONotificationCenter.h>
#import <Masonry/Masonry.h>
#import <SRGAnalytics_DataProvider/SRGAnalytics_DataProvider.h>
#import <SRGAppearance/SRGAppearance.h>
#import <SRGUserData/SRGUserData.h>

// Store the most recently used landscape orientation, also between player instantiations (so that the user last used
// orientation is preferred)
static UIDeviceOrientation s_previouslyUsedLandscapeDeviceOrientation = UIDeviceOrientationLandscapeLeft;

static const UILayoutPriority MediaPlayerBottomConstraintNormalPriority = 850;
static const UILayoutPriority MediaPlayerBottomConstraintFullScreenPriority = 950;

// Choose the good aspect ratio for the player view, depending of the screen size
static const UILayoutPriority MediaPlayerViewAspectRatioConstraintNormalPriority = 900;
static const UILayoutPriority MediaPlayerViewAspectRatioConstraintLowPriority = 700;

// Provide a collapsed version only if the ratio between expanded and collapsed heights is above a given value
// (it makes no sense to show a collapsed version if the expanded version is only slightly taller)
static const CGFloat MediaPlayerDetailsLabelExpansionThresholdFactor = 1.4f;
static const CGFloat MediaPlayerDetailsLabelCollapsedHeight = 90.f;

static const UILayoutPriority MediaPlayerDetailsLabelNormalPriority = 999;       // Cannot mutate priority of required installed constraints (throws an exception at runtime), so use lower priority
static const UILayoutPriority MediaPlayerDetailsLabelExpandedPriority = 300;

@interface MediaPlayerViewController ()

@property (nonatomic) NSString *originalURN;                                     // original URN to be played (otherwise rely on Letterbox controller information)
@property (nonatomic) SRGMedia *originalMedia;                                   // original media to be played (otherwise rely on Letterbox controller information)
@property (nonatomic) SRGLetterboxController *originalLetterboxController;       // optional source controller, will be used if provided
@property (nonatomic) SRGPosition *originalPosition;                             // original position to start at

@property (nonatomic) IBOutlet SRGLetterboxController *letterboxController;      // top object, strong

@property (nonatomic, getter=isFromPushNotification) BOOL fromPushNotification;

@property (nonatomic) NSArray<SRGMedia *> *livestreamMedias;                     // Media list for regional radio choice
@property (nonatomic, weak) SRGRequest *livestreamMediasRequest;

@property (nonatomic, weak) IBOutlet UIView *topBarView;
@property (nonatomic, weak) IBOutlet UIButton *closeButton;
@property (nonatomic, weak) IBOutlet GCKUICastButton *googleCastButton;
@property (nonatomic, weak) IBOutlet UIButton *downloadButton;
@property (nonatomic, weak) IBOutlet UIButton *subscriptionButton;
@property (nonatomic, weak) IBOutlet UIButton *watchLaterButton;
@property (nonatomic, weak) IBOutlet UIButton *shareButton;

@property (nonatomic, weak) IBOutlet UIView *playerView;
@property (nonatomic, weak) IBOutlet SRGLetterboxView *letterboxView;

@property (nonatomic, weak) IBOutlet UIView *livestreamView;                     // Regional radio selector
@property (nonatomic, weak) IBOutlet UIButton *livestreamButton;
@property (nonatomic, weak) IBOutlet UIImageView *livestreamButtonImageView;

@property (nonatomic, weak) IBOutlet UILabel *titleLabel;
@property (nonatomic, weak) IBOutlet UILabel *availabilibityLabel;

@property (nonatomic, weak) IBOutlet UIScrollView *scrollView;

@property (nonatomic, weak) IBOutlet UIStackView *mediaInfoStackView;
@property (nonatomic, weak) IBOutlet UIImageView *thumbnailImageView;
@property (nonatomic, weak) IBOutlet UIStackView *showStackView;
@property (nonatomic, weak) IBOutlet UILabel *showLabel;
@property (nonatomic, weak) IBOutlet UIStackView *dateStackView;
@property (nonatomic, weak) IBOutlet UILabel *dateLabel;
@property (nonatomic, weak) IBOutlet UIStackView *viewCountStackView;
@property (nonatomic, weak) IBOutlet UIImageView *viewCountImageView;
@property (nonatomic, weak) IBOutlet UILabel *viewCountLabel;
@property (nonatomic, weak) IBOutlet UILabel *summaryLabel;
@property (nonatomic, weak) IBOutlet UIView *youthProtectionColorSpacerView;
@property (nonatomic, weak) IBOutlet UIStackView *youthProtectionColorStackView;
@property (nonatomic, weak) IBOutlet UIImageView *youthProtectionColorImageView;
@property (nonatomic, weak) IBOutlet UILabel *youthProtectionColorLabel;
@property (nonatomic, weak) IBOutlet UIView *imageCopyrightSpacerView;
@property (nonatomic, weak) IBOutlet UILabel *imageCopyrightLabel;

// The details button might appear at different locations depending on the layout. A button is placed at all possible
// location, and we will ensure only the first one is visible.
@property (nonatomic) IBOutletCollection(UIButton) NSArray *detailsButtons;

@property (nonatomic, weak) IBOutlet UIStackView *channelInfoStackView;
@property (nonatomic, weak) IBOutlet UILabel *programTimeLabel;
@property (nonatomic, weak) IBOutlet UILabel *nextProgramLabel;
@property (nonatomic, weak) IBOutlet UILabel *channelLabel;

@property (nonatomic, weak) IBOutlet UIView *radioHomeView;
@property (nonatomic, weak) IBOutlet UIButton *radioHomeButton;
@property (nonatomic, weak) IBOutlet UIImageView *radioHomeButtonImageView;

@property (nonatomic, weak) IBOutlet UILabel *relatedContentsTitleLabel;
@property (nonatomic, weak) IBOutlet UIStackView *relatedContentsStackView;

@property (nonatomic, weak) IBOutlet LiveAccessView *liveAccessView;

// Switching to and from full-screen is made by adjusting the priority of a constraint at the bottom of the player view
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *playerBottomConstraint;

// Showing details is made by disabling the following height constraint property
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *collapsedDetailsLabelsHeightConstraint;

// Displaying segments (if any) is achieved by adding a small offset to the player aspect ratio constraint
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *playerAspectRatio16_9Constraint;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *playerAspectRatioBigLandscapeScreenConstraint;

@property (nonatomic, weak) IBOutlet UIGestureRecognizer *detailsGestureRecognizer;
@property (nonatomic, weak) IBOutlet UIPanGestureRecognizer *pullDownGestureRecognizer;

@property (nonatomic, weak) UIPinchGestureRecognizer *pinchGestureRecognizer;

@property (nonatomic, getter=isTransitioning) BOOL transitioning;           // Whether the UI is currently transitioning between class sizes
@property (nonatomic, getter=isStatusBarHidden) BOOL statusBarHidden;

@property (nonatomic, getter=areDetailsExpanded) BOOL detailsExpanded;
@property (nonatomic, getter=areDetailsAvailable) BOOL detailsAvailable;
@property (nonatomic, getter=isShowingPopup) BOOL showingPopup;

@property (nonatomic) ModalTransition *interactiveTransition;

@property (nonatomic) NSTimer *userInterfaceUpdateTimer;

@end

@implementation MediaPlayerViewController

#pragma mark Object lifecycle

- (instancetype)initWithURN:(NSString *)URN position:(SRGPosition *)position fromPushNotification:(BOOL)fromPushNotification
{
    SRGLetterboxService *service = SRGLetterboxService.sharedService;
    
    // If an equivalent view controller was dismissed for picture in picture of the same media, simply restore it
    if (service.controller.pictureInPictureActive && [service.pictureInPictureDelegate isKindOfClass:self.class] && [service.controller.URN isEqual:URN]) {
        return (MediaPlayerViewController *)service.pictureInPictureDelegate;
    }
    // Hook to the existing service controller if already playing the media
    else if ([service.controller.URN isEqual:URN]) {
        return [self initWithController:service.controller position:position fromPushNotification:fromPushNotification];
    }
    // Otherwise instantiate a fresh instance
    else {
        if (self = [super init]) {
            self.originalURN = URN;
            self.originalPosition = position;
            self.fromPushNotification = fromPushNotification;
            ApplicationConfigurationApplyControllerSettings(self.letterboxController);
        }
        return self;
    }
}

- (instancetype)initWithMedia:(SRGMedia *)media position:(SRGPosition *)position fromPushNotification:(BOOL)fromPushNotification
{
    SRGLetterboxService *service = SRGLetterboxService.sharedService;
    
    // If an equivalent view controller was dismissed for picture in picture of the same media, simply restore it
    if (service.controller.pictureInPictureActive && [service.pictureInPictureDelegate isKindOfClass:self.class] && [service.controller.URN isEqual:media.URN]) {
        return (MediaPlayerViewController *)service.pictureInPictureDelegate;
    }
    // Hook to the existing service controller if already playing the media
    else if ([service.controller.URN isEqual:media.URN]) {
        return [self initWithController:service.controller position:position fromPushNotification:fromPushNotification];
    }
    // Otherwise instantiate a fresh instance
    else {
        if (self = [super init]) {
            self.originalMedia = media;
            self.originalPosition = position;
            self.fromPushNotification = fromPushNotification;
            ApplicationConfigurationApplyControllerSettings(self.letterboxController);
        }
        return self;
    }
}

- (instancetype)initWithController:(SRGLetterboxController *)controller position:(SRGPosition *)position fromPushNotification:(BOOL)fromPushNotification
{
    if (self = [super init]) {
        self.originalLetterboxController = controller;
        self.originalPosition = position;
        self.fromPushNotification = fromPushNotification;
        
        // Force at init the correct Letterbox controller. In the `viewDidLoad:`, link it to the Letterbox view.
        self.letterboxController = controller;
    }
    return self;
}

- (void)dealloc
{
    // Invalidate timers
    self.userInterfaceUpdateTimer = nil;
}

#pragma mark Getters and setters

- (void)setUserInterfaceUpdateTimer:(NSTimer *)userInterfaceUpdateTimer
{
    [_userInterfaceUpdateTimer invalidate];
    _userInterfaceUpdateTimer = userInterfaceUpdateTimer;
}

- (void)setLetterboxController:(SRGLetterboxController *)letterboxController
{
    [_letterboxController removeObserver:self keyPath:@keypath(_letterboxController.continuousPlaybackUpcomingMedia)];
    
    _letterboxController = letterboxController;
    
    @weakify(self)
    @weakify(letterboxController)
    [letterboxController addObserver:self keyPath:@keypath(letterboxController.continuousPlaybackUpcomingMedia) options:0 block:^(MAKVONotification *notification) {
        @strongify(self)
        @strongify(letterboxController)
        
        [self updateDownloadStatus];
        [self updateWatchLaterStatus];
        [self updateSharingStatus];
        
        [self updateSubscriptionStatus];
        
        if (letterboxController.continuousPlaybackUpcomingMedia) {
            SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
            labels.source = AnalyticsSourceAutomatic;
            labels.type = AnalyticsTypeActionDisplay;
            labels.value = letterboxController.continuousPlaybackUpcomingMedia.URN;
            
            Playlist *playlist = [letterboxController.playlistDataSource isKindOfClass:Playlist.class] ? letterboxController.playlistDataSource : nil;
            labels.extraValue1 = playlist.recommendationUid;
            [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleContinuousPlayback labels:labels];
        }
    }];
}

- (RadioChannel *)radioChannel
{
    SRGMedia *media = self.letterboxController.subdivisionMedia ?: self.letterboxController.media;
    NSString *channelUid = self.letterboxController.channel.uid ?: media.channel.uid ?: media.show.primaryChannelUid;
    return [[ApplicationConfiguration sharedApplicationConfiguration] radioChannelForUid:channelUid];
}

#pragma mark Overrides

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.transitioningDelegate = self;
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = UIColor.play_blackColor;
    
    self.thumbnailImageView.backgroundColor = UIColor.play_grayThumbnailImageViewBackgroundColor;
    
    self.pullDownGestureRecognizer.delegate = self;
    
    self.scrollView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    
    // Start with an empty summary label, so that height calculations correctly detect when a summary has been assigned
    self.summaryLabel.text = nil;
    
    // Ensure consistent initial layout constraint priorities
    self.playerBottomConstraint.priority = MediaPlayerBottomConstraintNormalPriority;
    self.collapsedDetailsLabelsHeightConstraint.priority = MediaPlayerDetailsLabelNormalPriority;
    
    self.livestreamButton.backgroundColor = UIColor.play_lightGrayButtonBackgroundColor;
    self.livestreamButton.layer.cornerRadius = 4.f;
    self.livestreamButton.layer.masksToBounds = YES;
    [self.livestreamButton setTitle:NSLocalizedString(@"Choose a regional radio", @"Title displayed on the regional radio selection button") forState:UIControlStateNormal];
    
    self.livestreamButtonImageView.tintColor = UIColor.whiteColor;
    
    self.livestreamButton.accessibilityHint = PlaySRGAccessibilityLocalizedString(@"Select regional radio", @"Regional livestream selection hint");
    
    self.radioHomeButton.backgroundColor = [UIColor play_lightGrayButtonBackgroundColor];
    self.radioHomeButton.layer.cornerRadius = 4.f;
    self.radioHomeButton.layer.masksToBounds = YES;
    [self.radioHomeButton setTitle:nil forState:UIControlStateNormal];
    
    // iPhone devices: Set full screen in landscape orientation (done before the view is actually displayed. This
    // avoids status bar hiccups)
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        UIDeviceOrientation deviceOrientation = UIDevice.currentDevice.orientation;
        BOOL isLandscape = UIDeviceOrientationIsValidInterfaceOrientation(deviceOrientation) ? UIDeviceOrientationIsLandscape(deviceOrientation) : UIInterfaceOrientationIsLandscape(UIApplication.sharedApplication.statusBarOrientation);
        self.statusBarHidden = isLandscape;
        
        self.transitioning = isLandscape;
        [self.letterboxView setFullScreen:isLandscape animated:NO];
        self.transitioning = NO;
    }
    
    // Use original controller, if any has been provided
    if (self.originalLetterboxController) {
        self.letterboxView.controller = self.letterboxController;
        
        // Always resume playback if the original controller was not playing
        [self.letterboxController play];
    }
    else {
        self.letterboxController.contentURLOverridingBlock = ^(NSString *URN) {
            Download *download = [Download downloadForURN:URN];
            return download.localMediaFileURL;
        };
        
        if (self.originalMedia) {
            [self.letterboxController playMedia:self.originalMedia atPosition:self.originalPosition withPreferredSettings:ApplicationSettingPlaybackSettings()];
        }
        else {
            [self.letterboxController playURN:self.originalURN atPosition:self.originalPosition withPreferredSettings:ApplicationSettingPlaybackSettings()];
        }
    }
    
    self.liveAccessView.letterboxController = self.letterboxController;
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(mediaMetadataDidChange:)
                                               name:SRGLetterboxMetadataDidChangeNotification
                                             object:self.letterboxController];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(playbackStateDidChange:)
                                               name:SRGLetterboxPlaybackStateDidChangeNotification
                                             object:self.letterboxController];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(playbackDidFail:)
                                               name:SRGLetterboxPlaybackDidFailNotification
                                             object:self.letterboxController];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(applicationWillEnterForeground:)
                                               name:UIApplicationWillEnterForegroundNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(reachabilityDidChange:)
                                               name:FXReachabilityStatusDidChangeNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(playlistsDidChange:)
                                               name:SRGPlaylistsDidChangeNotification
                                             object:SRGUserData.currentUserData.playlists];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(downloadStateDidChange:)
                                               name:DownloadStateDidChangeNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(accessibilityVoiceOverStatusChanged:)
                                               name:UIAccessibilityVoiceOverStatusChanged
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(googleCastStateDidChange:)
                                               name:kGCKCastStateDidChangeNotification
                                             object:nil];
    
    @weakify(self)
    self.userInterfaceUpdateTimer = [NSTimer play_timerWithTimeInterval:0.2 repeats:YES block:^(NSTimer * _Nonnull timer) {
        @strongify(self)
        [self updateGoogleCastButton];
        
        // Ensure a save is triggered when handoff is used, so that the current position is properly updated in the
        // transmitted information.
        self.userActivity.needsSave = YES;
    }];
    [self updateGoogleCastButton];
    
    // When letterboxController is set, update livestream button
    [self updateLivestreamButton];
    
    // Force UI visibility for audios, start with no controls for videos
    SRGMedia *media = self.originalLetterboxController.media ?: self.originalMedia;
    [self setUserInterfaceBehaviorForMedia:media animated:NO];
    
    [SRGLetterboxService.sharedService enableWithController:self.letterboxController pictureInPictureDelegate:self];
    
    self.closeButton.accessibilityLabel = PlaySRGAccessibilityLocalizedString(@"Close", @"Close button label on player view");
    self.shareButton.accessibilityLabel = PlaySRGAccessibilityLocalizedString(@"Share", @"Share button label on player view");
    
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        UIPinchGestureRecognizer *pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
        pinchGestureRecognizer.delegate = self;
        [self.letterboxView addGestureRecognizer:pinchGestureRecognizer];
        self.pinchGestureRecognizer = pinchGestureRecognizer;
    }
    
    [self reloadDataOverriddenWithMedia:nil mainChapterMedia:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (self.letterboxController.mediaComposition) {
        // Do not send additional page view events when the interactive transition has been cancelled
        if (! self.transitionCoordinator.cancelled) {
            [self srg_trackPageView];
        }
    }
    
    self.userActivity = [[NSUserActivity alloc] initWithActivityType:[NSBundle.mainBundle.bundleIdentifier stringByAppendingString:@".playing"]];
    self.userActivity.delegate = self;
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    if (self.letterboxController.continuousPlaybackUpcomingMedia) {
        SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
        labels.source = AnalyticsSourceClose;
        labels.type = AnalyticsTypeActionCancel;
        labels.value = self.letterboxController.continuousPlaybackUpcomingMedia.URN;
        
        Playlist *playlist = [self.letterboxController.playlistDataSource isKindOfClass:Playlist.class] ? self.letterboxController.playlistDataSource : nil;
        labels.extraValue1 = playlist.recommendationUid;
        [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleContinuousPlayback labels:labels];
    }
    
    [self.letterboxController cancelContinuousPlayback];
    
    if ([self play_isMovingFromParentViewController]) {
        if (UIDevice.play_deviceType == DeviceTypePhoneOther) {
            [UIDevice.currentDevice setValue:@(UIInterfaceOrientationPortrait) forKey:@keypath(UIDevice.new, orientation)];
        }
        
        if (self.letterboxController.media.mediaType != SRGMediaTypeAudio && ! self.letterboxController.pictureInPictureActive) {
            [SRGLetterboxService.sharedService disableForController:self.letterboxController];
        }
        
        [self.livestreamMediasRequest cancel];
    }
    else if (self.letterboxController.media.mediaType == SRGMediaTypeVideo) {
        [self.letterboxController pause];
    }
    
    self.userActivity = nil;
    
    self.fromPushNotification = NO;
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    [self updateDetailsAppearance];
}

#pragma mark Responsiveness

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    self.transitioning = YES;
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        // iPhone devices: Set full screen when switching to landscape orientation (no change when switching to portrait,
        // when switching to landscape we want the experience to be as immersive as possible, but when switching to portrait
        // we don't want to alter the current experience)
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
            BOOL isLandscape = (size.width > size.height);
            [self.letterboxView setFullScreen:isLandscape animated:NO /* will be animated with the view transition */];
            
            if (isLandscape && self.letterboxView.userInterfaceTogglable
                    && ! UIAccessibilityIsVoiceOverRunning()
                    && self.letterboxController.playbackState != SRGMediaPlayerPlaybackStatePaused
                    && self.letterboxController.playbackState != SRGMediaPlayerPlaybackStateEnded) {
                [self.letterboxView setUserInterfaceHidden:YES animated:NO /* will be animated with the view transition */];
            }
        }
        [self updateLiveAccessButtonsVisibilityForFullScreen:self.letterboxView.fullScreen];
        [self updatePlayerViewAspectRatioWithSize:size];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        UIDeviceOrientation deviceOrientation = UIDevice.currentDevice.orientation;
        if (UIDeviceOrientationIsLandscape(deviceOrientation)) {
            s_previouslyUsedLandscapeDeviceOrientation = deviceOrientation;
        }
        self.transitioning = NO;
    }];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    
    [self updatePlayerViewAspectRatioWithSize:self.view.frame.size];
}

#pragma mark Accessibility

- (void)updateForContentSizeCategory
{
    [super updateForContentSizeCategory];
    
    [self reloadDataOverriddenWithMedia:nil mainChapterMedia:nil];
}

- (BOOL)accessibilityPerformEscape
{
    [self dismissViewControllerAnimated:YES completion:^{
        [StoreReview requestReview];
    }];
    return YES;
}

#pragma mark Status bar

- (BOOL)prefersStatusBarHidden
{
    return self.statusBarHidden;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation
{
    return UIStatusBarAnimationSlide;
}

#pragma mark Home indicator

- (BOOL)prefersHomeIndicatorAutoHidden
{
    return self.letterboxView.fullScreen && self.letterboxView.userInterfaceHidden;
}

#pragma mark UIResponder (ActivityContinuation)

- (void)updateUserActivityState:(NSUserActivity *)userActivity
{
    [super updateUserActivityState:userActivity];
    
    [self synchronizeUserActivity:userActivity];
}

#pragma mark NSUserActivityDelegate protocol

- (void)userActivityWillSave:(NSUserActivity *)userActivity
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self synchronizeUserActivity:userActivity];
    });
}

- (void)userActivityWasContinued:(NSUserActivity *)userActivity
{
    if ([userActivity isEqual:self.userActivity]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.letterboxController pause];
            [Banner showWithStyle:BannerStyleInfo
                          message:NSLocalizedString(@"Playback has resumed on another device.", @"Notification message when a media is paused due to Handoff activity.")
                            image:nil
                           sticky:NO
                 inViewController:self];
        });
    }
}

#pragma mark Handoff

- (void)synchronizeUserActivity:(NSUserActivity *)userActivity
{
    SRGMedia *mainMedia = [self.letterboxController.mediaComposition mediaForSubdivision:self.letterboxController.mediaComposition.mainChapter];
    if (mainMedia) {
        userActivity.title = mainMedia.title;
        if (mainMedia.endDate) {
            userActivity.expirationDate = mainMedia.endDate;
        }
        
        NSNumber *position = nil;
        CMTime currentTime = self.letterboxController.currentTime;
        if (CMTIME_IS_VALID(currentTime)
                && self.letterboxController.playbackState != SRGMediaPlayerPlaybackStateIdle
                && self.letterboxController.playbackState != SRGMediaPlayerPlaybackStatePreparing
                && self.letterboxController.playbackState != SRGMediaPlayerPlaybackStateEnded) {
            position = @((NSInteger)CMTimeGetSeconds(currentTime));
        }
        else {
            currentTime = kCMTimeZero;
        }
        [userActivity addUserInfoEntriesFromDictionary:@{ @"URNString" : mainMedia.URN,
                                                          @"SRGMediaData" : [NSKeyedArchiver archivedDataWithRootObject:mainMedia],
                                                          @"position" : position ?: [NSNull null],
                                                          @"applicationVersion" : [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] }];
        userActivity.requiredUserInfoKeys = [NSSet setWithArray:userActivity.userInfo.allKeys];
        userActivity.webpageURL = [ApplicationConfiguration.sharedApplicationConfiguration sharingURLForMediaMetadata:mainMedia atTime:currentTime];
    }
    else {
        [userActivity resignCurrent];
    }
}

#pragma mark Data display

- (void)reloadDataOverriddenWithMedia:(SRGMedia *)media mainChapterMedia:(SRGMedia *)mainChapterMedia
{
    if (! media) {
        media = self.letterboxController.subdivisionMedia ?: self.letterboxController.media;
    }
    if (! mainChapterMedia) {
        mainChapterMedia = [self mainChapterMedia];
    }
    [self updateAppearanceWithDetailsExpanded:self.detailsExpanded];
    [self reloadDetailsWithMedia:media mainChapterMedia:mainChapterMedia];
    
    UIImage *closeButtonImage = (media.mediaType == SRGMediaTypeAudio) ? [UIImage imageNamed:@"arrow_down-48"] : [UIImage imageNamed:@"close-48"];
    [self.closeButton setImage:closeButtonImage forState:UIControlStateNormal];
    
    self.relatedContentsTitleLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleBody];
    self.relatedContentsTitleLabel.text = NSLocalizedString(@"More on this subject", @"Title of the related content player section");
    
    // Cleanup related content views first
    NSPredicate *relatedContentViewsPredicate = [NSPredicate predicateWithBlock:^BOOL(id _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return [evaluatedObject isKindOfClass:RelatedContentView.class];
    }];
    
    NSArray<UIView *> *relatedContentViews = [self.relatedContentsStackView.arrangedSubviews filteredArrayUsingPredicate:relatedContentViewsPredicate];
    for (UIView *relatedContentView in relatedContentViews) {
        [relatedContentView removeFromSuperview];
    }
    
    // Related contents are available from the chapter
    SRGChapter *chapter = self.letterboxController.mediaComposition.mainChapter;
    NSArray<SRGRelatedContent *> *relatedContents = chapter.relatedContents;
    if (relatedContents.count != 0) {
        for (SRGRelatedContent *relatedContent in relatedContents) {
            RelatedContentView *relatedContentView = [RelatedContentView view];
            relatedContentView.relatedContent = relatedContent;
            [self.relatedContentsStackView addArrangedSubview:relatedContentView];
        }
        
        [self.relatedContentsStackView play_setHidden:NO];
    }
    else {
        [self.relatedContentsStackView play_setHidden:YES];
    }
    
    [self updateWatchLaterStatus];
    [self updateSubscriptionStatus];
    
    [self updateliveAccessViewContentForMediaType:media.mediaType force:NO];
}

// Details panel reloading
- (void)reloadDetailsWithMedia:(SRGMedia *)media mainChapterMedia:(SRGMedia *)mainChapterMedia
{
    self.livestreamView.hidden = [self isLivestreamButtonHidden];
    self.livestreamButton.titleLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleBody];
    
    self.titleLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleTitle];
    
    [self.availabilibityLabel play_displayAvailabilityLabelForMediaMetadata:mainChapterMedia];
    
    // Livestream: Display channel information when available
    if (media.contentType == SRGContentTypeLivestream) {
        [self.mediaInfoStackView play_setHidden:YES];
        
        SRGLetterboxController *letterboxController = self.letterboxController;
        SRGChannel *channel = letterboxController.channel;
        if (channel) {
            [self.channelInfoStackView play_setHidden:NO];
            
            SRGProgram *currentProgram = channel.currentProgram;
            if ([self isSliderDateContainedInProgram:currentProgram]) {
                self.titleLabel.text = currentProgram.title;
                
                self.channelLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleSubtitle];
                self.channelLabel.text = channel.title;
                
                self.programTimeLabel.font = [UIFont srg_lightFontWithTextStyle:SRGAppearanceFontTextStyleBody];
                self.programTimeLabel.text = [NSString stringWithFormat:@"%@ - %@", [NSDateFormatter.play_timeFormatter stringFromDate:currentProgram.startDate], [NSDateFormatter.play_timeFormatter stringFromDate:currentProgram.endDate]];
                self.programTimeLabel.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"From %1$@ to %2$@", @"Text to inform a program time information, like the current program"), [NSDateFormatter.play_relativeTimeAccessibilityFormatter stringFromDate:currentProgram.startDate], [NSDateFormatter.play_relativeTimeAccessibilityFormatter stringFromDate:currentProgram.endDate]];
            }
            else {
                self.titleLabel.text = channel.title;
                self.channelLabel.text = nil;
                self.programTimeLabel.text = nil;
                self.programTimeLabel.accessibilityLabel = nil;
            }
            
            SRGProgram *nextProgram = channel.nextProgram;
            if (nextProgram) {
                self.nextProgramLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleSubtitle];
                NSString *nextProgramFormat = [NSString stringWithFormat:@"> %@", NSLocalizedString(@"At %1$@: %2$@", @"Introductory text for next program information")];
                self.nextProgramLabel.text = nextProgram ? [NSString stringWithFormat:nextProgramFormat, [NSDateFormatter.play_relativeTimeFormatter stringFromDate:nextProgram.startDate], nextProgram.title] : nil;
                self.nextProgramLabel.accessibilityLabel = nextProgram ? [NSString stringWithFormat:nextProgramFormat, [NSDateFormatter.play_relativeTimeAccessibilityFormatter stringFromDate:nextProgram.startDate], nextProgram.title] : nil;
            }
            else {
                self.nextProgramLabel.text = nil;
                self.nextProgramLabel.accessibilityLabel = nil;
            }
        }
        else {
            self.titleLabel.text = media.title;
            
            [self.channelInfoStackView play_setHidden:YES];
        }
    }
    // Other streams: Display media information
    else {
        self.titleLabel.text = media.title;
        
        [self.mediaInfoStackView play_setHidden:NO];
        [self.channelInfoStackView play_setHidden:YES];
        
        [self.thumbnailImageView play_requestImageForObject:media withScale:ImageScaleSmall type:SRGImageTypeDefault placeholder:ImagePlaceholderMedia];
        
        self.dateLabel.font = [UIFont srg_lightFontWithTextStyle:SRGAppearanceFontTextStyleBody];
        self.dateLabel.text = [NSDateFormatter.play_relativeDateAndTimeFormatter stringFromDate:media.date].play_localizedUppercaseFirstLetterString;
        self.dateLabel.accessibilityLabel = [NSDateFormatter.play_relativeDateAndTimeAccessibilityFormatter stringFromDate:media.date];
        
        if (media.show) {
            self.showLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleBody];
            self.showLabel.text = media.show.title;
            self.showLabel.accessibilityLabel = (media.show.title) ? [NSString stringWithFormat:PlaySRGAccessibilityLocalizedString(@"Episode of %@ show", @"In the player, show description label"), media.show.title] : nil;
            [self.showStackView play_setHidden:NO];
        }
        else {
            [self.showStackView play_setHidden:YES];
        }
        
        self.viewCountLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleCaption];
        
        NSPredicate *socialViewsPredicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGSocialCount.new, type), @(SRGSocialCountTypeSRGView)];
        SRGSocialCount *socialCount = [media.socialCounts filteredArrayUsingPredicate:socialViewsPredicate].firstObject;
        if (socialCount && socialCount.value >= ApplicationConfiguration.sharedApplicationConfiguration.minimumSocialViewCount) {
            if (media.mediaType == SRGMediaTypeAudio) {
                self.viewCountLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%@ listenings", @"Label displaying the number of listenings on the player"), @(socialCount.value)];
                self.viewCountLabel.accessibilityLabel = [NSString stringWithFormat:PlaySRGAccessibilityLocalizedString(@"%@ listenings", @"Label displaying the number of listenings on the player"), @(socialCount.value)];
                self.viewCountImageView.image = [UIImage imageNamed:@"viewCountAudio-16"];
            }
            else {
                self.viewCountLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%@ views", @"Label displaying the number of views on the player"), @(socialCount.value)];
                self.viewCountLabel.accessibilityLabel = [NSString stringWithFormat:PlaySRGAccessibilityLocalizedString(@"%@ views", @"Label displaying the number of views on the player"), @(socialCount.value)];
                self.viewCountImageView.image = [UIImage imageNamed:@"viewCountVideo-16"];
            }
            [self.viewCountStackView play_setHidden:NO];
        }
        else {
            [self.viewCountStackView play_setHidden:YES];
        }
    }
    
#if defined(DEBUG) || defined(NIGHTLY) || defined(BETA)
    // Display 🔒 in the title if the stream is protected with a DRM.
    if (self.letterboxController.resource.DRMs.count > 0) {
        self.titleLabel.text = (self.titleLabel.text != nil) ? [@"🔒 " stringByAppendingString:self.titleLabel.text] : @"🔒";
    }
#endif
    
    self.summaryLabel.font = [UIFont srg_regularFontWithTextStyle:SRGAppearanceFontTextStyleBody];
    self.summaryLabel.text = media.play_fullSummary;
    
    [self updateRadioHomeButton];
    self.radioHomeButton.titleLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleBody];
    
    UIImage *youthProtectionColorImage = YouthProtectionImageForColor(media.youthProtectionColor);
    if (youthProtectionColorImage) {
        self.youthProtectionColorImageView.image = YouthProtectionImageForColor(media.youthProtectionColor);
        self.youthProtectionColorLabel.font = [UIFont srg_lightFontWithTextStyle:SRGAppearanceFontTextStyleSubtitle];
        self.youthProtectionColorLabel.text = SRGMessageForYouthProtectionColor(media.youthProtectionColor);
        self.youthProtectionColorSpacerView.hidden = NO;
        self.youthProtectionColorStackView.hidden = NO;
    }
    else {
        self.youthProtectionColorImageView.image = nil;
        self.youthProtectionColorLabel.text = nil;
        self.youthProtectionColorSpacerView.hidden = YES;
        self.youthProtectionColorStackView.hidden = YES;
    }
    
    NSString *imageCopyright = media.imageCopyright;
    if (imageCopyright) {
        self.imageCopyrightLabel.font = [UIFont srg_italicFontWithTextStyle:SRGAppearanceFontTextStyleSubtitle];
        self.imageCopyrightLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Image credit: %@", @"Image copyright introductory label"), imageCopyright];
        self.imageCopyrightSpacerView.hidden = NO;
    }
    else {
        self.imageCopyrightLabel.text = nil;
        self.imageCopyrightSpacerView.hidden = YES;
    }
    
    [self updateDownloadStatusForMedia:mainChapterMedia];
    [self updateWatchLaterStatusForMedia:mainChapterMedia];
    [self updateSharingStatusForMedia:mainChapterMedia];
    
    [self updateSubscriptionStatus];
}

#pragma mark UI

- (void)setUserInterfaceBehaviorForMedia:(SRGMedia *)media animated:(BOOL)animated
{
    if (media.mediaType == SRGMediaTypeAudio) {
        [self.letterboxView setUserInterfaceHidden:NO animated:animated togglable:NO];
    }
    else {
        [self.letterboxView setUserInterfaceHidden:! UIAccessibilityIsVoiceOverRunning() animated:animated togglable:YES];
    }
}

- (void)setFullScreen:(BOOL)fullScreen
{
    self.pullDownGestureRecognizer.enabled = ! fullScreen;
    self.playerBottomConstraint.priority = fullScreen ? MediaPlayerBottomConstraintFullScreenPriority : MediaPlayerBottomConstraintNormalPriority;
    [self updateLiveAccessButtonsVisibilityForFullScreen:fullScreen];
    
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)setDetailsExpanded:(BOOL)expanded animated:(BOOL)animated
{
    if (self.detailsExpanded == expanded) {
        return;
    }
    
    void (^animations)(void) = ^{
        [self updateAppearanceWithDetailsExpanded:expanded];
    };
    
    self.detailsExpanded = expanded;
    
    if (animated) {
        [self.view layoutIfNeeded];
        [UIView animateWithDuration:0.2 animations:^{
            animations();
            [self.view layoutIfNeeded];
        } completion:nil];
    }
    else {
        animations();
    }
}

- (void)updateAppearanceWithDetailsExpanded:(BOOL)expanded
{
    // Change to expanded mode (set low priority for height restriction, so that vertical content hugging dominates)
    if (expanded) {
        self.collapsedDetailsLabelsHeightConstraint.priority = MediaPlayerDetailsLabelExpandedPriority;
        
        [self.detailsButtons enumerateObjectsUsingBlock:^(UIButton * _Nonnull button, NSUInteger idx, BOOL * _Nonnull stop) {
            button.transform = CGAffineTransformMakeRotation(M_PI);
        }];
    }
    // Change to collapsed mode (set high priority for height restriction)
    else {
        self.collapsedDetailsLabelsHeightConstraint.priority = MediaPlayerDetailsLabelNormalPriority;
        
        [self.detailsButtons enumerateObjectsUsingBlock:^(UIButton * _Nonnull button, NSUInteger idx, BOOL * _Nonnull stop) {
            // Use small value so that the arrow always rotates in the inverse direction
            button.transform = CGAffineTransformMakeRotation(0.00001);
        }];
    }
}

- (void)updatePlayerViewAspectRatioWithSize:(CGSize)size
{
    // Use the big landscape screen aspect ratio for player view in landscape orientation on iPad, 16:9 ratio otherwise.
    BOOL isLandscape = (size.width > size.height);
    if (self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassRegular
            && self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular
            && isLandscape) {
        self.playerAspectRatio16_9Constraint.priority = MediaPlayerViewAspectRatioConstraintLowPriority;
        self.playerAspectRatioBigLandscapeScreenConstraint.priority = MediaPlayerViewAspectRatioConstraintNormalPriority;
    }
    else {
        self.playerAspectRatio16_9Constraint.priority = MediaPlayerViewAspectRatioConstraintNormalPriority;
        self.playerAspectRatioBigLandscapeScreenConstraint.priority = MediaPlayerViewAspectRatioConstraintLowPriority;
    }
}

- (void)updateDetailsAppearance
{
    // No need for a details button if not necessary or if the expanded version is only slightly taller than the collapsed one.
    BOOL isDetailsButtonHidden = NO;
    if (self.summaryLabel.text) {
        CGFloat summaryLabelHeight = self.summaryLabel.intrinsicContentSize.height;
        if (summaryLabelHeight / MediaPlayerDetailsLabelCollapsedHeight <= MediaPlayerDetailsLabelExpansionThresholdFactor) {
            [self.detailsButtons enumerateObjectsUsingBlock:^(UIButton * _Nonnull button, NSUInteger idx, BOOL * _Nonnull stop) {
                button.hidden = YES;
            }];
            self.detailsGestureRecognizer.enabled = NO;
            isDetailsButtonHidden = YES;
            
            self.detailsAvailable = NO;
            self.collapsedDetailsLabelsHeightConstraint.constant = summaryLabelHeight;
        }
        else {
            self.detailsAvailable = YES;
            self.collapsedDetailsLabelsHeightConstraint.constant = MediaPlayerDetailsLabelCollapsedHeight;
            
            [self.detailsButtons enumerateObjectsUsingBlock:^(UIButton * _Nonnull button, NSUInteger idx, BOOL * _Nonnull stop) {
                button.hidden = NO;
            }];
            self.detailsGestureRecognizer.enabled = YES;
        }
    }
    else {
        self.detailsAvailable = NO;
        self.collapsedDetailsLabelsHeightConstraint.constant = 0.f;
        
        [self.detailsButtons enumerateObjectsUsingBlock:^(UIButton * _Nonnull button, NSUInteger idx, BOOL * _Nonnull stop) {
            button.hidden = YES;
        }];
        self.detailsGestureRecognizer.enabled = NO;
        isDetailsButtonHidden = YES;
    }
    
    // Make the first button whose direct parent is actually visible the only possibly visible details button
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == NO", @keypath(UIButton.new, superview.play_isActuallyHidden)];
    NSArray<UIButton *> *visibleDetailsButtons = [self.detailsButtons filteredArrayUsingPredicate:predicate];
    [visibleDetailsButtons enumerateObjectsUsingBlock:^(UIButton * _Nonnull button, NSUInteger idx, BOOL * _Nonnull stop) {
        button.hidden = YES;
    }];
    visibleDetailsButtons.firstObject.hidden = isDetailsButtonHidden || UIAccessibilityIsVoiceOverRunning();
}

- (SRGMedia *)mainChapterMedia
{
    if (self.letterboxController.mediaComposition) {
        return [self.letterboxController.mediaComposition mediaForSubdivision:self.letterboxController.mediaComposition.mainChapter];
    }
    else if (self.letterboxController.media && [Download downloadForMedia:self.letterboxController.media]) {
        return self.letterboxController.media;
    }
    
    return nil;
}

- (SRGShow *)mainShow
{
    SRGMedia *mainChapterMedia = [self mainChapterMedia];
    if (mainChapterMedia.contentType == SRGContentTypeLivestream) {
        SRGProgram *currentProgram = self.letterboxController.channel.currentProgram;
        if ([self isSliderDateContainedInProgram:currentProgram]) {
            return currentProgram.show;
        }
        else {
            return nil;
        }
    }
    else {
        return mainChapterMedia.show;
    }
}

- (void)updateSharingStatus
{
    [self updateSharingStatusForMedia:[self mainChapterMedia]];
}

- (void)updateSharingStatusForMedia:(SRGMedia *)media
{
    if (self.letterboxController.continuousPlaybackUpcomingMedia) {
        self.shareButton.hidden = YES;
    }
    else {
        self.shareButton.hidden = ([ApplicationConfiguration.sharedApplicationConfiguration sharingURLForMediaMetadata:media atTime:kCMTimeZero] == nil);
    }
}

- (void)updateWatchLaterStatus
{
    [self updateWatchLaterStatusForMedia:[self mainChapterMedia]];
}

- (void)updateWatchLaterStatusForMedia:(SRGMedia *)media
{
    if (self.letterboxController.continuousPlaybackUpcomingMedia || ! media) {
        self.watchLaterButton.hidden = YES;
        return;
    }
    
    self.watchLaterButton.hidden = NO;
    
    if (WatchLaterContainsMediaMetadata(media)) {
        [self.watchLaterButton setImage:[UIImage imageNamed:@"watch_later_full-48"] forState:UIControlStateNormal];
        self.watchLaterButton.accessibilityLabel = PlaySRGAccessibilityLocalizedString(@"Remove from \"Watch later\" list", @"Media watch later removal label");
    }
    else {
        [self.watchLaterButton setImage:[UIImage imageNamed:@"watch_later-48"] forState:UIControlStateNormal];
        self.watchLaterButton.accessibilityLabel = PlaySRGAccessibilityLocalizedString(@"Add to \"Watch later\" list", @"Media watch later creation label");
    }
}

- (void)updateDownloadStatus
{
    [self updateDownloadStatusForMedia:[self mainChapterMedia]];
}

- (void)updateDownloadStatusForMedia:(SRGMedia *)media
{
    if (self.letterboxController.continuousPlaybackUpcomingMedia || ! media || ! [Download canDownloadMedia:media]) {
        self.downloadButton.hidden = YES;
        return;
    }
    
    self.downloadButton.hidden = NO;
    
    Download *download = [Download downloadForMedia:media];
    
    UIImage *downloadButtonImage = nil;
    NSString *downloadButtonAccessibilityLabel = nil;
    
    switch (download.state) {
        case DownloadStateAdded:
        case DownloadStateDownloadingSuspended:{
            [self.downloadButton.imageView play_stopAnimating];
            
            downloadButtonImage = [UIImage imageNamed:@"downloadable_stop-48"];
            downloadButtonAccessibilityLabel = PlaySRGAccessibilityLocalizedString(@"Retry download", @"A download button label");
            break;
        }
            
        case DownloadStateDownloading: {
            [self.downloadButton.imageView play_startAnimatingDownloading48WithTintColor:UIColor.whiteColor];
            
            downloadButtonImage = self.downloadButton.imageView.image;
            downloadButtonAccessibilityLabel = PlaySRGAccessibilityLocalizedString(@"Stop downloading", @"A download button label");
            break;
        }
            
        case DownloadStateDownloaded: {
            [self.downloadButton.imageView play_stopAnimating];
            
            downloadButtonImage = [UIImage imageNamed:@"downloadable_full-48"];
            downloadButtonAccessibilityLabel = PlaySRGAccessibilityLocalizedString(@"Remove download", @"A download button label");
            break;
        }
            
        default: {
            [self.downloadButton.imageView play_stopAnimating];
            
            downloadButtonImage = [UIImage imageNamed:@"downloadable-48"];
            downloadButtonAccessibilityLabel = PlaySRGAccessibilityLocalizedString(@"Download", @"A download button label");
            break;
        }
    }
    
    [self.downloadButton setImage:downloadButtonImage forState:UIControlStateNormal];
    self.downloadButton.accessibilityLabel = downloadButtonAccessibilityLabel;
}

- (void)updateSubscriptionStatus
{
    PushService *pushService = PushService.sharedService;
    if (! pushService || self.letterboxController.continuousPlaybackUpcomingMedia) {
        self.subscriptionButton.hidden = YES;
        return;
    }
    
    SRGShow *show = [self mainShow];
    if (! show) {
        self.subscriptionButton.hidden = YES;
        return;
    }
    
    self.subscriptionButton.hidden = NO;
    
    BOOL subscribed = [pushService isSubscribedToShow:show];
    if (subscribed) {
        [self.subscriptionButton setImage:[UIImage imageNamed:@"subscription_full-48"] forState:UIControlStateNormal];
        self.subscriptionButton.accessibilityLabel = PlaySRGAccessibilityLocalizedString(@"Unsubscribe from show", @"Show unsubscription label");
    }
    else {
        [self.subscriptionButton setImage:[UIImage imageNamed:@"subscription-48"] forState:UIControlStateNormal];
        self.subscriptionButton.accessibilityLabel = PlaySRGAccessibilityLocalizedString(@"Subscribe to show", @"Show subscription label");
    }
}

- (void)updateliveAccessViewContentForMediaType:(SRGMediaType)mediaType force:(BOOL)force
{
    if (self.liveAccessView.mediaType == mediaType && ! force) {
        [self.liveAccessView updateLiveAccessButtonsSelection];
    }
    else {
        @weakify(self)
        [self.liveAccessView refreshWithMediaType:mediaType withCompletionBlock:^(NSError * _Nullable error) {
            @strongify(self)
            [self updateLiveAccessButtonsVisibilityForFullScreen:self.letterboxView.fullScreen];
        }];
    }
    
    [self updateLiveAccessButtonsVisibilityForFullScreen:self.letterboxView.fullScreen];
}

- (void)updateLiveAccessButtonsVisibilityForFullScreen:(BOOL)fullScreen
{
    BOOL hidden = (self.liveAccessView.medias.count == 0)
        || fullScreen
        || ((self.liveAccessView.medias.count == 1) && [self.liveAccessView.medias.firstObject isEqual:self.letterboxController.media]);
    self.liveAccessView.hidden = hidden;
    
    CGFloat height = hidden ? 0.f : LiveAccessView.height;
    UIEdgeInsets insets = UIEdgeInsetsMake(0.f, 0.f, height, 0.f);
    self.scrollView.contentInset = insets;
    self.scrollView.scrollIndicatorInsets = insets;
    
    [self.view layoutIfNeeded];
}

- (void)updateGoogleCastButton
{
    SRGBlockingReason blockingReason = [self.letterboxController.media blockingReasonAtDate:NSDate.date];
    self.googleCastButton.hidden = self.letterboxController.playbackState == SRGMediaPlayerPlaybackStateIdle
        || self.letterboxController.playbackState == SRGMediaPlayerPlaybackStateEnded
        || self.letterboxController.playbackState == SRGMediaPlayerPlaybackStatePreparing
        || blockingReason != SRGBlockingReasonNone
        || [GCKCastContext sharedInstance].castState == GCKCastStateNoDevicesAvailable;
}

- (BOOL)isLivestreamButtonHidden
{
    SRGMedia *media = self.letterboxController.media;
    return ! media || ! [self.livestreamMedias containsObject:media] || self.livestreamMedias.count < 2;
}

- (void)updateLivestreamButton
{
    SRGMedia *media = self.letterboxController.media;
    
    if (! media || media.contentType != SRGContentTypeLivestream || media.channel.transmission != SRGTransmissionRadio) {
        self.livestreamMedias = nil;
        [self.livestreamMediasRequest cancel];
        
        self.livestreamView.hidden = [self isLivestreamButtonHidden];
        return;
    }
    
    if (self.livestreamMedias.count > 0 && ! [self.livestreamMedias containsObject:media]) {
        self.livestreamMedias = nil;
        [self.livestreamMediasRequest cancel];
    }
    
    self.livestreamView.hidden = [self isLivestreamButtonHidden];
    
    if (! self.livestreamMediasRequest) {
        ApplicationConfiguration *applicationConfiguration = ApplicationConfiguration.sharedApplicationConfiguration;
        SRGRequest *request = [SRGDataProvider.currentDataProvider radioLivestreamsForVendor:applicationConfiguration.vendor channelUid:media.channel.uid withCompletionBlock:^(NSArray<SRGMedia *> * _Nullable medias, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
            self.livestreamMedias = medias;
            self.livestreamView.hidden = [self isLivestreamButtonHidden];
        }];
        [request resume];
        self.livestreamMediasRequest = request;
    }
}

- (BOOL)isSliderDateContainedInProgram:(SRGProgram *)program
{
    if (! program) {
        return NO;
    }
    
    NSDate *currentDate = self.letterboxView.date;
    return ! currentDate || [program play_containsDate:currentDate];
}

- (void)updateRadioHomeButton
{
    RadioChannel *radioChannel = [self radioChannel];
    self.radioHomeView.hidden = (radioChannel == nil);
    self.radioHomeButtonImageView.image = RadioChannelLogo22Image(radioChannel);
    
    // Avoid ugly animation when setting the title, see https://stackoverflow.com/a/22101732/760435
    [UIView performWithoutAnimation:^{
        [self.radioHomeButton setTitle:[NSString stringWithFormat:NSLocalizedString(@"%@ overview", @"Title displayed on the radio home button"), radioChannel.name] forState:UIControlStateNormal];
        [self.radioHomeButton layoutIfNeeded];
    }];
}

#pragma mark SRGAnalyticsViewTracking protocol

- (BOOL)srg_isTrackedAutomatically
{
    // Tracking requires media composition information. The view event will be sent manually when appropriate
    return NO;
}

- (NSString *)srg_pageViewTitle
{
    // Use the full-length when available
    SRGMedia *media = self.letterboxController.fullLengthMedia ?: self.letterboxController.media;
    return media.title;
}

- (NSArray<NSString *> *)srg_pageViewLevels
{
    NSMutableArray<NSString *> *levels = [NSMutableArray array];
    
    // Use the full-length when available
    SRGMedia *media = self.letterboxController.fullLengthMedia ?: self.letterboxController.media;
    if (media.mediaType == SRGMediaTypeAudio) {
        [levels addObject:AnalyticsNameForPageType(AnalyticsPageTypeRadio)];
    }
    else {
        [levels addObject:AnalyticsNameForPageType(AnalyticsPageTypeTV)];
    }
    [levels addObject:@"detail"];
    
    NSString *showTitle = self.letterboxController.mediaComposition.show.title;
    if (showTitle) {
        [levels addObject:showTitle];
    }
    
    return [levels copy];
}

- (BOOL)srg_isOpenedFromPushNotification
{
    return self.fromPushNotification;
}

#pragma mark SRGLetterboxViewDelegate protocol

- (void)letterboxViewWillAnimateUserInterface:(SRGLetterboxView *)letterboxView
{
    [self.view layoutIfNeeded];
    [letterboxView animateAlongsideUserInterfaceWithAnimations:^(BOOL hidden, BOOL minimal, CGFloat timelineHeight) {
        self.topBarView.alpha = (minimal || ! hidden) ? 1.f : 0.f;
        self.playerAspectRatio16_9Constraint.constant = timelineHeight;
        self.playerAspectRatioBigLandscapeScreenConstraint.constant = timelineHeight;
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        [self play_setNeedsUpdateOfHomeIndicatorAutoHidden];
    }];
}

- (void)letterboxView:(SRGLetterboxView *)letterboxView toggleFullScreen:(BOOL)fullScreen animated:(BOOL)animated withCompletionHandler:(nonnull void (^)(BOOL))completionHandler
{ 
    // On iPhones, full-screen transitions are always trigerred by rotation. Even when tapping on the full-screen button,
    // we force a rotation, which itself will perform the appropriate transition from or to full-screen
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone && ! self.transitioning) {
        // We interrupt the rotation attempt and trigger a rotation (which itself will toggle the expected full-screen display)
        completionHandler(NO);
        
        if (UIInterfaceOrientationIsLandscape(UIApplication.sharedApplication.statusBarOrientation)) {
            [UIDevice.currentDevice setValue:@(UIInterfaceOrientationPortrait) forKey:@keypath(UIDevice.new, orientation)];
        }
        else {
            [UIDevice.currentDevice setValue:@(s_previouslyUsedLandscapeDeviceOrientation) forKey:@keypath(UIDevice.new, orientation)];
        }
        return;
    }
    
    self.statusBarHidden = fullScreen;
    
    void (^animations)(void) = ^{
        [self setFullScreen:fullScreen];
    };
    
    void (^completion)(BOOL) = ^(BOOL finished) {
        [self play_setNeedsUpdateOfHomeIndicatorAutoHidden];
        completionHandler(finished);
    };
    
    if (animated) {
        [self.view layoutIfNeeded];
        [UIView animateWithDuration:0.2 animations:^{
            animations();
            [self.view layoutIfNeeded];
        } completion:completion];
    }
    else {
        animations();
        completion(YES);
    }
}

- (void)letterboxView:(SRGLetterboxView *)letterboxView didScrollWithSubdivision:(SRGSubdivision *)subdivision time:(CMTime)time interactive:(BOOL)interactive
{
    if (interactive) {
        SRGMedia *media = subdivision ? [self.letterboxController.mediaComposition mediaForSubdivision:subdivision] : self.letterboxController.fullLengthMedia;
        [self reloadDataOverriddenWithMedia:media mainChapterMedia:[self mainChapterMedia]];
    }
    else {
        [self updateSubscriptionStatus];
    }
}

- (void)letterboxView:(SRGLetterboxView *)letterboxView didSelectSubdivision:(SRGSubdivision *)subdivision
{
    // Delay user interface dismissal. This improves the user experience and, for physical video segments (which are
    // togglable), this fixes a conflicting UI behavior (switching physical media makes the player display controls
    // again, which conflicts with an attempt to immediately hide them).
    if (letterboxView.userInterfaceTogglable) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [letterboxView setUserInterfaceHidden:! UIAccessibilityIsVoiceOverRunning() animated:YES];
        });
    }
}

- (void)letterboxView:(SRGLetterboxView *)letterboxView didEngageInContinuousPlaybackWithUpcomingMedia:(SRGMedia *)upcomingMedia
{
    SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
    labels.source = AnalyticsSourceButton;
    labels.type = AnalyticsTypeActionPlayMedia;
    labels.value = upcomingMedia.URN;
    
    SRGLetterboxController *controller = letterboxView.controller;
    Playlist *playlist = [controller.playlistDataSource isKindOfClass:Playlist.class] ? controller.playlistDataSource : nil;
    labels.extraValue1 = playlist.recommendationUid;
    [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleContinuousPlayback labels:labels];
}

- (void)letterboxView:(SRGLetterboxView *)letterboxView didCancelContinuousPlaybackWithUpcomingMedia:(SRGMedia *)upcomingMedia
{
    // Processes run once in the lifetime of the application
    PlayApplicationRunOnce(^(void (^completionHandler)(BOOL success)) {
        NSUserDefaults *userDefaults = NSUserDefaults.standardUserDefaults;
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Keep autoplay?", @"Title of the alert view to keep autoplay permanently")
                                                                                 message:NSLocalizedString(@"You can manage this feature in the settings at any time.", @"Description of the alert view to keep autoplay permanently")
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Disable", @"Label for the button disabling autoplay") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            [userDefaults setBool:NO forKey:PlaySRGSettingAutoplayEnabled];
            [userDefaults synchronize];
            completionHandler(YES);
        }]];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Keep", @"Label for the button keeping autoplay enabled") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            completionHandler(YES);
        }]];
        [self presentViewController:alertController animated:YES completion:nil];
    }, @"DisableAutoplayAsked", nil);
    
    SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
    labels.source = AnalyticsSourceButton;
    labels.type = AnalyticsTypeActionCancel;
    labels.value = upcomingMedia.URN;
    
    SRGLetterboxController *controller = letterboxView.controller;
    Playlist *playlist = [controller.playlistDataSource isKindOfClass:Playlist.class] ? controller.playlistDataSource : nil;
    labels.extraValue1 = playlist.recommendationUid;
    [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleContinuousPlayback labels:labels];
}

- (void)letterboxView:(SRGLetterboxView *)letterboxView didLongPressSubdivision:(SRGSubdivision *)subdivision
{
    SRGMedia *media = [self.letterboxController.mediaComposition mediaForSubdivision:subdivision];
    WatchLaterAddMediaMetadata(media, ^(NSError * _Nullable error) {
        if (! error) {
            [Banner showWatchLaterAdded:YES forItemWithName:media.title inViewController:self];
        }
    });
}

#pragma mark SRGLetterboxPictureInPictureDelegate protocol

- (BOOL)letterboxDismissUserInterfaceForPictureInPicture
{
    [self dismissViewControllerAnimated:YES completion:nil];
    return YES;
}

- (BOOL)letterboxShouldRestoreUserInterfaceForPictureInPicture
{
    // Present the media player view controller again if needed
    UIViewController *topViewController = UIApplication.sharedApplication.keyWindow.play_topViewController;
    return ! [topViewController isKindOfClass:MediaPlayerViewController.class];
}

- (void)letterboxRestoreUserInterfaceForPictureInPictureWithCompletionHandler:(void (^)(BOOL))completionHandler
{
    UIViewController *topViewController = UIApplication.sharedApplication.keyWindow.play_topViewController;
    [topViewController presentViewController:self animated:YES completion:^{
        completionHandler(YES);
    }];
}

- (void)letterboxDidStartPictureInPicture
{
    SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
    labels.value = self.letterboxController.fullLengthMedia.URN;
    [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitlePictureInPicture labels:labels];
}

#pragma mark UIGestureRecognizerDelegate protocol

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if (gestureRecognizer == self.pullDownGestureRecognizer || gestureRecognizer == self.pinchGestureRecognizer) {
        return ! [touch.view isKindOfClass:UISlider.class];
    }
    else {
        return YES;
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if (gestureRecognizer == self.pullDownGestureRecognizer) {
        return [otherGestureRecognizer.view isKindOfClass:UIScrollView.class];
    }
    else {
        return NO;
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if (gestureRecognizer == self.pullDownGestureRecognizer) {
        return [otherGestureRecognizer isKindOfClass:SRGActivityGestureRecognizer.class];
    }
    else if (gestureRecognizer == self.pinchGestureRecognizer) {
        return [otherGestureRecognizer isKindOfClass:SRGActivityGestureRecognizer.class];
    }
    else {
        return NO;
    }
}

#pragma mark UIViewControllerTransitioningDelegate protocol

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source
{
    return [[ModalTransition alloc] initForPresentation:YES];
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed
{
    // Always return the transition
    return [[ModalTransition alloc] initForPresentation:NO];
}

- (id<UIViewControllerInteractiveTransitioning>)interactionControllerForDismissal:(id<UIViewControllerAnimatedTransitioning>)animator
{
    // Return the installed interactive transition, if any
    return self.interactiveTransition;
}

#pragma mark Actions

- (IBAction)toggleWatchLater:(id)sender
{
    SRGMedia *mainChapterMedia = [self mainChapterMedia];
    if (! mainChapterMedia) {
        return;
    }
    
    WatchLaterToggleMediaMetadata(mainChapterMedia, ^(BOOL added, NSError * _Nullable error) {
        if (!error) {
            AnalyticsTitle analyticsTitle = added ? AnalyticsTitleWatchLaterAdd : AnalyticsTitleWatchLaterRemove;
            SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
            labels.source = AnalyticsSourceButton;
            labels.value = mainChapterMedia.URN;
            [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:analyticsTitle labels:labels];
            
            [Banner showWatchLaterAdded:added forItemWithName:mainChapterMedia.title inViewController:self];
        }
    });
}

- (IBAction)toggleSubscription:(id)sender
{
    PushService *pushService = PushService.sharedService;
    if (! pushService) {
        return;
    }
    
    SRGShow *show = [self mainShow];
    
    BOOL toggled = [pushService toggleSubscriptionForShow:show inViewController:self];
    if (! toggled) {
        return;
    }
    
    [self updateSubscriptionStatus];
    
    BOOL subscribed = [pushService isSubscribedToShow:show];
    
    AnalyticsTitle analyticsTitle = (subscribed) ? AnalyticsTitleSubscriptionAdd : AnalyticsTitleSubscriptionRemove;
    SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
    labels.source = AnalyticsSourceButton;
    labels.value = show.URN;
    [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:analyticsTitle labels:labels];
    
    [Banner showSubscription:subscribed forShowWithName:show.title inViewController:self];
}

- (IBAction)toggleDownload:(id)sender
{
    SRGMedia *media = [self mainChapterMedia];
    if (! media || ! [Download canDownloadMedia:media]) {
        return;
    }
    
    Download *download = [Download downloadForMedia:media];
    
    void (^toggleDownload)(void) = ^{
        if (! download) {
            [Download addDownloadForMedia:media];
        }
        else {
            [Download removeDownload:download];
        }
        
        [self updateDownloadStatus];
        
        AnalyticsTitle analyticsTitle = (download) ? AnalyticsTitleDownloadAdd : AnalyticsTitleDownloadRemove;
        SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
        labels.source = AnalyticsSourceButton;
        labels.value = media.URN;
        [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:analyticsTitle labels:labels];
    };
    
    if (!download) {
        toggleDownload();
    }
    else {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Remove download", @"Title of the confirmation pop-up displayed when the user is about to delete a download")
                                                                                 message:NSLocalizedString(@"Are you sure you want to delete the downloaded media?", @"Confirmation message displayed when the user is about to delete a download")
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Title of the cancel button in the alert view when deleting a download in the player view") style:UIAlertActionStyleDefault handler:nil]];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Delete", @"Title of the delete button in the alert view when deleting a download in the player view") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            toggleDownload();
        }]];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (IBAction)shareContent:(id)sender
{
    SRGMedia *mainMedia = [self mainChapterMedia];
    if (! mainMedia) {
        return;
    }
    
    ApplicationConfiguration *applicationConfiguration = ApplicationConfiguration.sharedApplicationConfiguration;
    NSURL *mainMediaURL = [applicationConfiguration sharingURLForMediaMetadata:mainMedia atTime:kCMTimeZero];
    if (! mainMediaURL) {
        return;
    }
    
    Float64 currentPosition = 0;
    NSURL *currentPositionURL = nil;
    
    SRGMedia *segmentMedia = nil;
    NSURL *segmentMediaURL = nil;
    
    if (mainMedia.contentType != SRGContentTypeLivestream && mainMedia.contentType != SRGContentTypeScheduledLivestream) {
        CMTime time = self.letterboxController.currentTime;
        if (CMTIME_IS_VALID(time)
                && CMTimeGetSeconds(time) >= 1.
                && self.letterboxController.playbackState != SRGMediaPlayerPlaybackStateIdle
                && self.letterboxController.playbackState != SRGMediaPlayerPlaybackStatePreparing
                && self.letterboxController.playbackState != SRGMediaPlayerPlaybackStateEnded) {
            currentPosition = CMTimeGetSeconds(time);
            currentPositionURL = [applicationConfiguration sharingURLForMediaMetadata:mainMedia atTime:time];
        }
        
        segmentMedia = ! [mainMedia isEqual:self.letterboxController.media] ? self.letterboxController.media : nil;
        segmentMediaURL = segmentMedia ? [applicationConfiguration sharingURLForMediaMetadata:segmentMedia atTime:kCMTimeZero] : nil;
    }
    
    void (^sharingCompletionBlock)(SRGMedia *, NSURL *, AnalyticsValue) = ^(SRGMedia *sharingMedia, NSURL *sharingURL, AnalyticsValue analyticsExtraValue) {
        ActivityItemSource *activityItemSource = [[ActivityItemSource alloc] initWithMedia:sharingMedia URL:sharingURL];
        UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[ activityItemSource ] applicationActivities:nil];
        activityViewController.excludedActivityTypes = @[ UIActivityTypeAssignToContact,
                                                          UIActivityTypeSaveToCameraRoll,
                                                          UIActivityTypePostToFlickr,
                                                          UIActivityTypePostToVimeo,
                                                          UIActivityTypePostToTencentWeibo ];
        activityViewController.completionWithItemsHandler = ^(UIActivityType __nullable activityType, BOOL completed, NSArray * __nullable returnedItems, NSError * __nullable activityError) {
            if (! completed) {
                return;
            }
            
            SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
            labels.type = activityType;
            labels.source = AnalyticsSourceButton;
            labels.value = sharingMedia.URN;
            labels.extraValue1 = analyticsExtraValue;
            [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleSharing labels:labels];
            
            SRGSubdivision *subdivision = [self.letterboxController.mediaComposition subdivisionWithURN:sharingMedia.URN];
            if (subdivision) {
                [[SRGDataProvider.currentDataProvider play_increaseSocialCountForActivityType:activityType subdivision:subdivision withCompletionBlock:^(SRGSocialCountOverview * _Nullable socialCountOverview, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
                    // Nothing
                }] resume];
            }
            
            if ([activityType isEqualToString:UIActivityTypeCopyToPasteboard]) {
                [Banner showWithStyle:BannerStyleInfo
                              message:NSLocalizedString(@"The content has been copied to the clipboard.", @"Message displayed when some content (media, show, etc.) has been copied to the clipboard")
                                image:nil
                               sticky:NO
                     inViewController:self];
            }
        };
        
        activityViewController.modalPresentationStyle = UIModalPresentationPopover;
        
        UIPopoverPresentationController *popoverPresentationController = activityViewController.popoverPresentationController;
        popoverPresentationController.sourceView = sender;
        popoverPresentationController.sourceRect = [sender bounds];
        
        [self presentViewController:activityViewController animated:YES completion:nil];
    };
    
    if (currentPositionURL || segmentMediaURL) {
        NSString *message = mainMedia.title;
        if (mainMedia.show.title && ! [mainMedia.title containsString:mainMedia.show.title]) {
            message = [NSString stringWithFormat:@"%@ ─ %@", mainMedia.show.title, mainMedia.title];
        }
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Share", @"Title of the action view to choose a sharing action") message:message preferredStyle:UIAlertControllerStyleActionSheet];
        
        if (segmentMediaURL) {
            [alertController addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"\"%@\"", segmentMedia.title] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                sharingCompletionBlock(segmentMedia, segmentMediaURL, AnalyticsTypeValueSharingCurrentClip);
            }]];
        }
        NSString *maintTitle = (mainMedia.contentType == SRGContentTypeEpisode) ? NSLocalizedString(@"The entire episode", @"Button label to share the entire episode being played.") : NSLocalizedString(@"The content", @"Button label to share the content being played.");
        [alertController addAction:[UIAlertAction actionWithTitle:maintTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            sharingCompletionBlock(mainMedia, mainMediaURL, AnalyticsTypeValueSharingContent);
        }]];
        
        if (currentPositionURL) {
            NSString *positionTitleFormat = (mainMedia.contentType == SRGContentTypeEpisode) ? NSLocalizedString(@"The episode at %@", @"Button label to share the entire episode being played at time (hours / minutes / seconds).") : NSLocalizedString(@"The content at %@", @"Button label to share the content being played at time (hours / minutes / seconds).");
            [alertController addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:positionTitleFormat, PlayHumanReadableFormattedDuration(currentPosition)] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                sharingCompletionBlock(mainMedia, currentPositionURL, AnalyticsTypeValueSharingContentAtTime);
            }]];
        }
        
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Label of the button to close the media sharing menu") style:UIAlertActionStyleCancel handler:nil]];
        alertController.modalPresentationStyle = UIModalPresentationPopover;
        
        UIPopoverPresentationController *popoverPresentationController = alertController.popoverPresentationController;
        popoverPresentationController.sourceView = sender;
        popoverPresentationController.sourceRect = [sender bounds];
        
        [self presentViewController:alertController animated:YES completion:nil];
    }
    else {
        sharingCompletionBlock(mainMedia, mainMediaURL, AnalyticsTypeValueSharingContent);
    }
}

- (IBAction)toggleDetails:(id)sender
{
    [self setDetailsExpanded:! self.detailsExpanded animated:YES];
}

- (IBAction)openRadioHome:(id)sender
{
    RadioChannel *radioChannel = [self radioChannel];
    if (! radioChannel) {
        return;
    }
    
    PlayAppDelegate *appDelegate = (PlayAppDelegate *)UIApplication.sharedApplication.delegate;
    appDelegate.sideMenuController.selectedMenuItemInfo = [MenuItemInfo menuItemInfoWithRadioChannel:radioChannel];
    [appDelegate.window play_dismissAllViewControllersAnimated:YES completion:nil];
}

- (IBAction)selectLivestreamMedia:(id)sender
{
    if ([self isLivestreamButtonHidden]) {
        return;
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Regional radios", @"Title of the action view to choose a regional radio")
                                                                             message:NSLocalizedString(@"Choose a regional radio", @"Information message of the action view to choose a regional radio")
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
    
    [self.livestreamMedias enumerateObjectsUsingBlock:^(SRGMedia * _Nonnull media, NSUInteger idx, BOOL * _Nonnull stop) {
        [alertController addAction:[UIAlertAction actionWithTitle:media.title style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            ApplicationSettingSetSelectedLiveStreamURNForChannelUid(media.channel.uid, media.URN);
            
            // Use the playback state if playing
            SRGMediaPlayerPlaybackState currentPlaybackState = self.letterboxController.playbackState;
            if (currentPlaybackState == SRGMediaPlayerPlaybackStatePlaying) {
                [self.letterboxController playMedia:media atPosition:nil withPreferredSettings:ApplicationSettingPlaybackSettings()];
            }
            else {
                [self.letterboxController prepareToPlayMedia:media atPosition:nil withPreferredSettings:ApplicationSettingPlaybackSettings() completionHandler:nil];
            }
            
            [self updateliveAccessViewContentForMediaType:media.mediaType force:YES];
        }]];
    }];
    
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Title of a cancel button") style:UIAlertActionStyleCancel handler:nil]];
    
    UIPopoverPresentationController *popoverPresentationController = alertController.popoverPresentationController;
    popoverPresentationController.sourceView = self.livestreamButtonImageView;
    popoverPresentationController.sourceRect = self.livestreamButtonImageView.bounds;
    popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (IBAction)close:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:^{
        [StoreReview requestReview];
    }];
}

#pragma mark Gesture recognizers

- (IBAction)pullDown:(UIPanGestureRecognizer *)panGestureRecognizer
{
    CGFloat progress = [panGestureRecognizer translationInView:self.view].y / CGRectGetHeight(self.view.frame);
    
    switch (panGestureRecognizer.state) {
        case UIGestureRecognizerStateBegan: {
            // Avoid duplicate dismissal (which can make it impossible to dismiss the view controller altogether)
            if (self.interactiveTransition) {
                return;
            }
            
            // Install the interactive transition animation before triggering it
            self.interactiveTransition = [[ModalTransition alloc] initForPresentation:NO];
            [self dismissViewControllerAnimated:YES completion:^{
                // Only stop tracking the interactive transition at the very end. The completion block is called
                // whether the transition ended or was cancelled
                self.interactiveTransition = nil;
                
                [StoreReview requestReview];
            }];
            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            [self.interactiveTransition updateInteractiveTransitionWithProgress:progress];
            break;
        }
            
        case UIGestureRecognizerStateFailed:
        case UIGestureRecognizerStateCancelled: {
            [self.interactiveTransition cancelInteractiveTransition];
            break;
        }
            
        case UIGestureRecognizerStateEnded: {
            CGFloat velocity = [panGestureRecognizer velocityInView:self.view].y;
            if (velocity > 0.f || (velocity == 0.f && progress > 0.5f)) {
                [self.interactiveTransition finishInteractiveTransition];
            }
            else {
                [self.interactiveTransition cancelInteractiveTransition];
            }
            break;
        }
            
        default: {
            break;
        }
    }
}

- (IBAction)toggleUserInterfaceVisibility:(UIGestureRecognizer *)gestureRecognizer
{
    if (self.letterboxView.userInterfaceTogglable) {
        [self.letterboxView setUserInterfaceHidden:! self.letterboxView.userInterfaceHidden animated:YES togglable:YES];
    }
}

- (IBAction)handlePinch:(UIPinchGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        [self.letterboxView setFullScreen:(gestureRecognizer.scale > 1.f) animated:YES];
    }
}

#pragma mark Notifications

- (void)mediaMetadataDidChange:(NSNotification *)notification
{
    // Store last audio livestream associated with the mini player for restoration when the application is restarted
    SRGMedia *media = notification.userInfo[SRGLetterboxMediaKey];
    if (media.contentType == SRGContentTypeLivestream && media.mediaType == SRGMediaTypeAudio) {
        [NSUserDefaults.standardUserDefaults setObject:media.URN forKey:PlaySRGSettingLastPlayedRadioLiveURN];
        [NSUserDefaults.standardUserDefaults synchronize];
    }
    
    if (media) {
        [self.userActivity becomeCurrent];
    }
    else {
        [self.userActivity resignCurrent];
    }
    
    SRGMedia *previousMedia = notification.userInfo[SRGLetterboxPreviousMediaKey];
    
    // Update the livestream button hidden state if media or URN changed
    if (! [media isEqual:previousMedia]) {
        [self updateLivestreamButton];
    }
    
    [self reloadDataOverriddenWithMedia:nil mainChapterMedia:nil];
    
    // When switching from video to audio or conversely, ensure the UI togglability is correct
    if (media.mediaType != previousMedia.mediaType) {
        [self setUserInterfaceBehaviorForMedia:media animated:YES];
    }
    
    // Notify page view when the full-length changes.
    SRGMediaComposition *previousMediaComposition = notification.userInfo[SRGLetterboxPreviousMediaCompositionKey];
    SRGMediaComposition *mediaComposition = notification.userInfo[SRGLetterboxMediaCompositionKey];
    
    if ([self isViewVisible] && mediaComposition && ! [previousMediaComposition.fullLengthMedia isEqual:mediaComposition.fullLengthMedia]) {
        [self srg_trackPageView];
        self.fromPushNotification = NO;
    }
}

- (void)playbackStateDidChange:(NSNotification *)notification
{
    if (self.letterboxController.media.mediaType == SRGMediaTypeAudio && [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePlaying) {
        self.closeButton.accessibilityHint = PlaySRGAccessibilityLocalizedString(@"Closes the player while continuing to play audio.", @"Player close button hint");
    }
    else {
        self.closeButton.accessibilityHint = nil;
    }
    
    if ([notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue] == SRGMediaPlayerPlaybackStatePreparing) {
        [self reloadDataOverriddenWithMedia:nil mainChapterMedia:nil];
    }
}

- (void)playbackDidFail:(NSNotification *)notification
{
    // Let the user access the top bar in case of an error
    self.topBarView.alpha = 1.f;
    
    self.closeButton.accessibilityHint = nil;
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    if (self.letterboxController.mediaComposition) {
        [self srg_trackPageView];
        self.fromPushNotification = NO;
    }
    
    // Refresh subscription status in case the user left to toggle notification in settings
    [self updateSubscriptionStatus];
}

- (void)reachabilityDidChange:(NSNotification *)notification
{
    if ([FXReachability sharedInstance].reachable) {
        [self reloadDataOverriddenWithMedia:nil mainChapterMedia:nil];
        
        if (self.livestreamMedias.count == 0) {
            [self updateLivestreamButton];
        }
    }
}

- (void)playlistsDidChange:(NSNotification *)notification
{
    if ([notification.userInfo[SRGPlaylistChangedUidsKey] containsObject:SRGWatchLaterPlaylistUid]) {
        NSDictionary<NSString *, NSArray<NSString *> *> *playlistEntryChanges = notification.userInfo[SRGPlaylistEntryChangesKey][SRGWatchLaterPlaylistUid];
        if (playlistEntryChanges && [playlistEntryChanges[SRGPlaylistEntryChangedUidsSubKey] containsObject:[self mainChapterMedia].URN]) {
            [self updateWatchLaterStatus];
        }
    }
}

- (void)downloadStateDidChange:(NSNotification *)notification
{
    [self updateDownloadStatus];
}

- (void)accessibilityVoiceOverStatusChanged:(NSNotification *)notification
{
    [self updateDetailsAppearance];
}

- (void)googleCastStateDidChange:(NSNotification *)notification
{
    GCKCastState castState = [notification.userInfo[kGCKNotificationKeyCastState] integerValue];
    if (castState == GCKCastStateConnected) {
        NSError *castError = nil;
        if (GoogleCastIsPossible(self.letterboxController.mediaComposition, &castError)) {
            // Dismiss the player in all cases. We don't want the player to be accessible anymore once Google Cast is
            // connected.
            UIViewController *presentingViewController = self.presentingViewController;
            [self dismissViewControllerAnimated:YES completion:^{
                [self.letterboxController pause];
                [presentingViewController play_presentMediaPlayerFromLetterboxController:self.letterboxController fromPushNotification:self.fromPushNotification animated:YES completion:nil];
            }];
        }
        else if (castError) {
            [Banner showWithStyle:BannerStyleInfo message:castError.localizedDescription image:nil sticky:NO inViewController:self];
        }
    }
}

@end
