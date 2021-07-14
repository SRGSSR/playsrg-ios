//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "MediaPlayerViewController.h"

#import "AccessibilityIdentifierConstants.h"
#import "ApplicationSettings.h"
#import "ApplicationSettingsConstants.h"
#import "AnalyticsConstants.h"
#import "ApplicationConfiguration.h"
#import "Banner.h"
#import "ChannelService.h"
#import "Download.h"
#import "Favorites.h"
#import "ForegroundTimer.h"
#import "GoogleCast.h"
#import "GradientView.h"
#import "History.h"
#import "Layout.h"
#import "ModalTransition.h"
#import "NSBundle+PlaySRG.h"
#import "NSDateFormatter+PlaySRG.h"
#import "NSString+PlaySRG.h"
#import "PlayAccessibilityFormatter.h"
#import "PlayAppDelegate.h"
#import "PlayApplication.h"
#import "PlayDurationFormatter.h"
#import "PlayErrors.h"
#import "Playlist.h"
#import "PlaySRG-Swift.h"
#import "ProgramHeaderView.h"
#import "ProgramTableViewCell.h"
#import "Reachability.h"
#import "RelatedContentView.h"
#import "SharingItem.h"
#import "SRGChannel+PlaySRG.h"
#import "SRGDataProvider+PlaySRG.h"
#import "SRGLetterboxController+PlaySRG.h"
#import "SRGMedia+PlaySRG.h"
#import "SRGMediaComposition+PlaySRG.h"
#import "SRGProgram+PlaySRG.h"
#import "SRGProgramComposition+PlaySRG.h"
#import "SRGResource+PlaySRG.h"
#import "StoreReview.h"
#import "TableView.h"
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

@import GoogleCast;
@import Intents;
@import libextobjc;
@import MAKVONotificationCenter;
@import SRGAnalyticsDataProvider;
@import SRGAppearance;
@import SRGUserData;

// Store the most recently used landscape orientation, also between player instantiations (so that the user last used
// orientation is preferred)
static UIInterfaceOrientation s_previouslyUsedLandscapeInterfaceOrientation = UIInterfaceOrientationLandscapeLeft;

static const UILayoutPriority MediaPlayerBottomConstraintNormalPriority = 850;
static const UILayoutPriority MediaPlayerBottomConstraintFullScreenPriority = 950;

// Provide a collapsed version only if the ratio between expanded and collapsed heights is above a given value
// (it makes no sense to show a collapsed version if the expanded version is only slightly taller)
static const CGFloat MediaPlayerDetailsLabelExpansionThresholdFactor = 1.4f;
static const CGFloat MediaPlayerDetailsLabelCollapsedHeight = 90.f;

static const UILayoutPriority MediaPlayerDetailsLabelNormalPriority = 999;       // Cannot mutate priority of required installed constraints (throws an exception at runtime), so use lower priority
static const UILayoutPriority MediaPlayerDetailsLabelExpandedPriority = 300;

static NSDateComponentsFormatter *MediaPlayerViewControllerSkipIntervalAccessibilityFormatter(void)
{
    static NSDateComponentsFormatter *s_dateComponentsFormatter;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        s_dateComponentsFormatter = [[NSDateComponentsFormatter alloc] init];
        s_dateComponentsFormatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
        s_dateComponentsFormatter.allowedUnits = NSCalendarUnitSecond;
    });
    return s_dateComponentsFormatter;
}

@interface MediaPlayerViewController ()

@property (nonatomic) NSString *originalURN;                                     // original URN to be played (otherwise rely on Letterbox controller information)
@property (nonatomic) SRGMedia *originalMedia;                                   // original media to be played (otherwise rely on Letterbox controller information)
@property (nonatomic) SRGLetterboxController *originalLetterboxController;       // optional source controller, will be used if provided
@property (nonatomic) SRGPosition *originalPosition;                             // original position to start at

@property (nonatomic) IBOutlet SRGLetterboxController *letterboxController;      // top object, strong

@property (nonatomic) SRGProgramComposition *programComposition;
@property (nonatomic) NSArray<SRGProgram *> *programs;

@property (nonatomic, getter=isFromPushNotification) BOOL fromPushNotification;

@property (nonatomic) NSArray<SRGMedia *> *livestreamMedias;                     // Media list for regional radio choice
@property (nonatomic, weak) SRGRequest *livestreamMediasRequest;

@property (nonatomic, weak) IBOutlet UIView *topBarView;
@property (nonatomic, weak) IBOutlet UIButton *closeButton;
@property (nonatomic, weak) IBOutlet GCKUICastButton *googleCastButton;
@property (nonatomic, weak) IBOutlet UIButton *downloadButton;
@property (nonatomic, weak) IBOutlet UIButton *watchLaterButton;
@property (nonatomic, weak) IBOutlet UIButton *shareButton;

@property (nonatomic, weak) IBOutlet UIView *playerView;
@property (nonatomic, weak) IBOutlet SRGLetterboxView *letterboxView;

// Normal appearance (on-demand, scheduled livestream)

@property (nonatomic, weak) IBOutlet UIScrollView *scrollView;

@property (nonatomic, weak) IBOutlet UILabel *titleLabel;
@property (nonatomic, weak) IBOutlet UILabel *availabilityLabel;
@property (nonatomic, weak) IBOutlet UIStackView *dateStackView;
@property (nonatomic, weak) IBOutlet UILabel *dateLabel;
@property (nonatomic, weak) IBOutlet UIImageView *viewCountImageView;
@property (nonatomic, weak) IBOutlet UILabel *viewCountLabel;
@property (nonatomic, weak) IBOutlet UIButton *detailsButton;
@property (nonatomic, weak) IBOutlet UILabel *summaryLabel;

@property (nonatomic, weak) IBOutlet UIView *propertiesTopLineSpacerView;
@property (nonatomic, weak) IBOutlet UIStackView *propertiesStackView;
@property (nonatomic, weak) IBOutlet UILabel *webFirstLabel;
@property (nonatomic, weak) IBOutlet UIImageView *subtitlesImageView;
@property (nonatomic, weak) IBOutlet UIImageView *audioDescriptionImageView;
@property (nonatomic, weak) IBOutlet UIImageView *multiAudioImageView;

@property (nonatomic, weak) IBOutlet UIView *showWrapperView;
@property (nonatomic, weak) IBOutlet UIStackView *showStackView;
@property (nonatomic, weak) IBOutlet UIImageView *showThumbnailImageView;
@property (nonatomic, weak) IBOutlet UILabel *showLabel;
@property (nonatomic, weak) IBOutlet UILabel *numberOfEpisodesLabel;
@property (nonatomic, weak) IBOutlet UIButton *favoriteButton;

@property (nonatomic, weak) IBOutlet UIView *radioHomeView;
@property (nonatomic, weak) IBOutlet UIButton *radioHomeButton;
@property (nonatomic, weak) IBOutlet UIImageView *radioHomeButtonImageView;

@property (nonatomic, weak) IBOutlet UIView *relatedContentsSpacerView;
@property (nonatomic, weak) IBOutlet UILabel *relatedContentsTitleLabel;
@property (nonatomic, weak) IBOutlet UIStackView *relatedContentsStackView;

@property (nonatomic, weak) IBOutlet UIView *youthProtectionColorSpacerView;
@property (nonatomic, weak) IBOutlet UIStackView *youthProtectionColorStackView;
@property (nonatomic, weak) IBOutlet UIImageView *youthProtectionColorImageView;
@property (nonatomic, weak) IBOutlet UILabel *youthProtectionColorLabel;
@property (nonatomic, weak) IBOutlet UIView *imageCopyrightSpacerView;
@property (nonatomic, weak) IBOutlet UILabel *imageCopyrightLabel;

// Live appearance

@property (nonatomic, weak) IBOutlet UIView *channelView;

@property (nonatomic, weak) IBOutlet UIStackView *channelInfoStackView;

@property (nonatomic, weak) IBOutlet UIView *livestreamView;                     // Regional radio selector
@property (nonatomic, weak) IBOutlet UIButton *livestreamButton;
@property (nonatomic, weak) IBOutlet UIImageView *livestreamButtonImageView;

@property (nonatomic, weak) IBOutlet GradientView *currentProgramView;
@property (nonatomic, weak) IBOutlet UIButton *currentProgramMoreEpisodesButton;
@property (nonatomic, weak) IBOutlet UILabel *currentProgramTitleLabel;
@property (nonatomic, weak) IBOutlet UILabel *currentProgramSubtitleLabel;
@property (nonatomic, weak) IBOutlet UIButton *currentProgramFavoriteButton;

@property (nonatomic, weak) IBOutlet UITableView *programsTableView;

// Switching to and from full-screen is made by adjusting the priority of constraints at the top and bottom of the player view
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *playerTopConstraint;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *playerBottomConstraint;

// When in full-screen mode, this 0-height constraint is enabled to ensure metadata view height is 0 (its priority stays at a normal value).
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *metadataHeightConstraint;

// Showing details is made by disabling the following height constraint property
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *collapsedDetailsLabelsHeightConstraint;

// The aspect ratio constant is used to display the player with the best possible aspect ratio, taking into account
// other frame changes into account (e.g. timeline display)
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *playerAspectRatioConstraint;

@property (nonatomic, weak) IBOutlet UIGestureRecognizer *detailsGestureRecognizer;
@property (nonatomic, weak) IBOutlet UIPanGestureRecognizer *pullDownGestureRecognizer;

@property (nonatomic, weak) UIPinchGestureRecognizer *pinchGestureRecognizer;

@property (nonatomic, getter=isTransitioning) BOOL transitioning;           // Whether the UI is currently transitioning between class sizes
@property (nonatomic, getter=isStatusBarHidden) BOOL statusBarHidden;

@property (nonatomic, getter=areDetailsExpanded) BOOL detailsExpanded;
@property (nonatomic, getter=areDetailsAvailable) BOOL detailsAvailable;
@property (nonatomic, getter=isShowingPopup) BOOL showingPopup;

@property (nonatomic) ModalTransition *interactiveTransition;

@property (nonatomic) ForegroundTimer *userInterfaceUpdateTimer;

@property (nonatomic) BOOL shouldDisplayBackgroundVideoPlaybackPrompt;
@property (nonatomic) BOOL displayBackgroundVideoPlaybackPrompt;

@property (nonatomic, weak) id channelObserver;

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
        if (self = [self initFromStoryboard]) {
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
        if (self = [self initFromStoryboard]) {
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
    if (self = [self initFromStoryboard]) {
        self.originalLetterboxController = controller;
        self.originalPosition = position;
        self.fromPushNotification = fromPushNotification;
        
        // Force the correct Letterbox controller. It will be linked to the Letterbox view in `-viewDidLoad`
        self.letterboxController = controller;
    }
    return self;
}

- (instancetype)initFromStoryboard
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:NSStringFromClass(self.class) bundle:nil];
    return storyboard.instantiateInitialViewController;
}

- (void)dealloc
{
    // Invalidate timers
    self.userInterfaceUpdateTimer = nil;
}

#pragma mark Getters and setters

- (void)setUserInterfaceUpdateTimer:(ForegroundTimer *)userInterfaceUpdateTimer
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
        
        if (letterboxController.continuousPlaybackUpcomingMedia) {
            SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
            labels.source = AnalyticsSourceAutomatic;
            labels.type = AnalyticsTypeActionDisplay;
            labels.value = letterboxController.continuousPlaybackUpcomingMedia.URN;
            
            Playlist *playlist = [letterboxController.playlistDataSource isKindOfClass:Playlist.class] ? (Playlist *)letterboxController.playlistDataSource : nil;
            labels.extraValue1 = playlist.recommendationUid;
            [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleContinuousPlayback labels:labels];
        }
    }];
}

- (NSString *)channelUid
{
    SRGMedia *media = self.letterboxController.subdivisionMedia ?: self.letterboxController.media;
    return self.letterboxController.channel.uid ?: media.channel.uid ?: media.show.primaryChannelUid;
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
    
    self.view.backgroundColor = UIColor.srg_gray16Color;
    
    self.scrollView.hidden = YES;
    self.channelView.hidden = YES;
    
    self.currentProgramView.backgroundColor = UIColor.srg_gray23Color;
    self.currentProgramView.layer.cornerRadius = LayoutStandardViewCornerRadius;
    self.currentProgramView.layer.masksToBounds = YES;
    
    self.currentProgramMoreEpisodesButton.accessibilityLabel = PlaySRGAccessibilityLocalizedString(@"More episodes", @"A more episode button label");
    
    TableViewConfigure(self.programsTableView);
    self.programsTableView.dataSource = self;
    self.programsTableView.delegate = self;
    
    // Remove the spaces at the top and bottom of the grouped table view
    // See https://stackoverflow.com/a/18938763/760435
    self.programsTableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0.f, 0.f, self.programsTableView.bounds.size.width, 0.01f)];
    self.programsTableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0.f, 0.f, self.programsTableView.bounds.size.width, 0.01f)];
            
    NSString *programCellIdentifier = NSStringFromClass(ProgramTableViewCell.class);
    UINib *programCellNib = [UINib nibWithNibName:programCellIdentifier bundle:nil];
    [self.programsTableView registerNib:programCellNib forCellReuseIdentifier:programCellIdentifier];
    
    NSString *programHeaderIdentifier = NSStringFromClass(ProgramHeaderView.class);
    UINib *programHeaderViewNib = [UINib nibWithNibName:programHeaderIdentifier bundle:nil];
    [self.programsTableView registerNib:programHeaderViewNib forHeaderFooterViewReuseIdentifier:programHeaderIdentifier];
    
    self.showWrapperView.backgroundColor = UIColor.srg_gray23Color;
    self.showWrapperView.layer.cornerRadius = LayoutStandardViewCornerRadius;
    self.showWrapperView.layer.masksToBounds = YES;
    
    self.showThumbnailImageView.backgroundColor = UIColor.play_grayThumbnailImageViewBackgroundColor;
    
    self.pullDownGestureRecognizer.delegate = self;
    
    self.scrollView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    
    // Start with an empty summary label, so that height calculations correctly detect when a summary has been assigned
    self.summaryLabel.text = nil;
    
    self.subtitlesImageView.accessibilityLabel = PlaySRGAccessibilityLocalizedString(@"Subtitled", @"Accessibility label for the subtitled badge");
    self.subtitlesImageView.accessibilityTraits = UIAccessibilityTraitStaticText;
    self.subtitlesImageView.isAccessibilityElement = YES;
    
    self.audioDescriptionImageView.accessibilityLabel = PlaySRGAccessibilityLocalizedString(@"Audio described", @"Accessibility label for the audio description badge");
    self.audioDescriptionImageView.accessibilityTraits = UIAccessibilityTraitStaticText;
    self.audioDescriptionImageView.isAccessibilityElement = YES;
    
    self.multiAudioImageView.accessibilityLabel = PlaySRGAccessibilityLocalizedString(@"Original version", @"Accessibility label for the multi audio badge");
    self.multiAudioImageView.accessibilityTraits = UIAccessibilityTraitStaticText;
    self.multiAudioImageView.isAccessibilityElement = YES;
    
    // Ensure consistent initial layout constraint priorities
    self.playerTopConstraint.priority = MediaPlayerBottomConstraintNormalPriority;
    self.playerBottomConstraint.priority = MediaPlayerBottomConstraintNormalPriority;
    self.metadataHeightConstraint.priority = MediaPlayerBottomConstraintNormalPriority;
    
    self.collapsedDetailsLabelsHeightConstraint.priority = MediaPlayerDetailsLabelNormalPriority;
    
    self.livestreamButton.backgroundColor = UIColor.srg_gray23Color;
    self.livestreamButton.layer.cornerRadius = LayoutStandardViewCornerRadius;
    self.livestreamButton.layer.masksToBounds = YES;
    self.livestreamButton.accessibilityHint = PlaySRGAccessibilityLocalizedString(@"Select regional radio", @"Regional livestream selection hint");
    
    self.livestreamButtonImageView.tintColor = UIColor.whiteColor;
    
    self.currentProgramView.accessibilityElements = @[ self.currentProgramTitleLabel, self.currentProgramMoreEpisodesButton, self.currentProgramFavoriteButton ];
    
    self.radioHomeButton.backgroundColor = UIColor.srg_gray23Color;
    self.radioHomeButton.layer.cornerRadius = LayoutStandardViewCornerRadius;
    self.radioHomeButton.layer.masksToBounds = YES;
    [self.radioHomeButton setTitle:nil forState:UIControlStateNormal];
    
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
                                           selector:@selector(segmentDidStart:)
                                               name:SRGLetterboxSegmentDidStartNotification
                                             object:self.letterboxController];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(segmentDidEnd:)
                                               name:SRGLetterboxSegmentDidEndNotification
                                             object:self.letterboxController];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(applicationWillResignActive:)
                                               name:UIApplicationWillResignActiveNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(applicationDidEnterBackground:)
                                               name:UIApplicationDidEnterBackgroundNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(applicationDidBecomeActive:)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(reachabilityDidChange:)
                                               name:FXReachabilityStatusDidChangeNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(playlistEntriesDidChange:)
                                               name:SRGPlaylistEntriesDidChangeNotification
                                             object:SRGUserData.currentUserData.playlists];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(downloadStateDidChange:)
                                               name:DownloadStateDidChangeNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(accessibilityVoiceOverStatusChanged:)
                                               name:UIAccessibilityVoiceOverStatusDidChangeNotification
                                             object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(contentSizeCategoryDidChange:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];
    
    @weakify(self)
    self.userInterfaceUpdateTimer = [ForegroundTimer timerWithTimeInterval:1. repeats:YES block:^(ForegroundTimer * _Nonnull timer) {
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
    
    self.closeButton.accessibilityLabel = PlaySRGAccessibilityLocalizedString(@"Close", @"Close button label on player view");
    self.closeButton.accessibilityIdentifier = AccessibilityIdentifierCloseButton;
    
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
    
    if ([self play_isMovingToParentViewController]) {
        [self registerForChannelUpdates];
        [self updateTimelineVisibilityForFullScreen:self.letterboxView.fullScreen animated:NO];
        
        [self scrollToNearestProgramAnimated:NO];
        [self updateSelectionForCurrentProgram];
        
        [self scrollToNearestSongAnimated:NO];
        [self updateSelectionForCurrentSong];
        
        [SRGLetterboxService.sharedService enableWithController:self.letterboxController pictureInPictureDelegate:self];
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
        
        Playlist *playlist = [self.letterboxController.playlistDataSource isKindOfClass:Playlist.class] ? (Playlist *)self.letterboxController.playlistDataSource : nil;
        labels.extraValue1 = playlist.recommendationUid;
        [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleContinuousPlayback labels:labels];
    }
    
    [self.letterboxController cancelContinuousPlayback];
    
    if ([self play_isMovingFromParentViewController]) {
        [self unregisterChannelUpdates];
        
        if (self.letterboxController.media.mediaType != SRGMediaTypeAudio
                && ! self.letterboxController.pictureInPictureActive
                && ! AVAudioSession.srg_isAirPlayActive
                && ! ApplicationSettingBackgroundVideoPlaybackEnabled()) {
            [SRGLetterboxService.sharedService disableForController:self.letterboxController];
            [StoreReview requestReview];
        }
        
        [self.livestreamMediasRequest cancel];
    }
    else if (self.letterboxController.media.mediaType == SRGMediaTypeVideo) {
        [self.letterboxController pause];
    }
    
    self.userActivity = nil;
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    [self updateDetailsAppearance];
}

#pragma mark Responsiveness

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    self.transitioning = YES;
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        // iPhone devices: Set full screen when switching to landscape orientation (no change when switching to portrait,
        // when switching to landscape we want the experience to be as immersive as possible, but when switching to portrait
        // we don't want to alter the current experience)
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
            BOOL isLandscape = (size.width > size.height);
            [self.letterboxView setFullScreen:isLandscape animated:NO /* will be animated with the view transition */];
            
            if (isLandscape) {
                [self hidePlayerUserInterfaceAnimated:NO /* will be animated with the view transition */];
            }
        }
        [self scrollToNearestProgramAnimated:NO];
        
        [self reloadSongPanelSize];
        [self scrollToNearestSongAnimated:NO];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        UIInterfaceOrientation interfaceOrientation = UIApplication.sharedApplication.delegate.window.windowScene.interfaceOrientation;
        if (UIInterfaceOrientationIsLandscape(interfaceOrientation)) {
            s_previouslyUsedLandscapeInterfaceOrientation = interfaceOrientation;
        }
        self.transitioning = NO;
    }];
}

- (void)willTransitionToTraitCollection:(UITraitCollection *)newCollection withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super willTransitionToTraitCollection:newCollection withTransitionCoordinator:coordinator];
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self updateSongPanelFor:newCollection fullScreen:self.letterboxView.fullScreen];
    } completion:nil];
}

#pragma mark Accessibility

- (BOOL)accessibilityPerformEscape
{
    [self play_dismissViewControllerAnimated:YES completion:nil];
    return YES;
}

#pragma mark Modal presentation

- (UIModalPresentationStyle)modalPresentationStyle
{
    return UIModalPresentationCustom;
}

- (BOOL)modalPresentationCapturesStatusBarAppearance
{
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

#pragma mark Handoff

- (void)synchronizeUserActivity:(NSUserActivity *)userActivity
{
    SRGMedia *mainChapterMedia = [self mainChapterMedia];
    if (mainChapterMedia) {
        NSString *userActivityTitleFormat = (mainChapterMedia.mediaType == SRGMediaTypeAudio) ? NSLocalizedString(@"Listen to %@", @"User activity title when listening to an audio") : NSLocalizedString(@"Watch %@", @"User activity title when watching a video");
        userActivity.title = [NSString stringWithFormat:userActivityTitleFormat, mainChapterMedia.title];
        if (mainChapterMedia.endDate) {
            userActivity.expirationDate = mainChapterMedia.endDate;
        }
        BOOL isLiveStream = (mainChapterMedia.contentType == SRGContentTypeLivestream);
        
        NSNumber *position = nil;
        CMTime currentTime = self.letterboxController.currentTime;
        if (! isLiveStream && CMTIME_IS_VALID(currentTime)
                && self.letterboxController.playbackState != SRGMediaPlayerPlaybackStateIdle
                && self.letterboxController.playbackState != SRGMediaPlayerPlaybackStatePreparing
                && self.letterboxController.playbackState != SRGMediaPlayerPlaybackStateEnded) {
            position = @((NSInteger)CMTimeGetSeconds(currentTime));
        }
        else {
            currentTime = kCMTimeZero;
        }
        [userActivity addUserInfoEntriesFromDictionary:@{ @"URNString" : mainChapterMedia.URN,
                                                          @"SRGMediaData" : [NSKeyedArchiver archivedDataWithRootObject:mainChapterMedia requiringSecureCoding:NO error:NULL],
                                                          @"position" : position ?: [NSNull null],
                                                          @"applicationVersion" : [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] }];
        userActivity.requiredUserInfoKeys = [NSSet setWithArray:userActivity.userInfo.allKeys];
        userActivity.webpageURL = [ApplicationConfiguration.sharedApplicationConfiguration sharingURLForMedia:mainChapterMedia atTime:currentTime];
        
        if (isLiveStream && mainChapterMedia.channel) {
            userActivity.eligibleForPrediction = YES;
            userActivity.persistentIdentifier = mainChapterMedia.URN;
            NSString *suggestedInvocationPhraseFormat = (mainChapterMedia.mediaType == SRGMediaTypeAudio) ? NSLocalizedString(@"Listen to %@", @"Suggested invocation phrase to listen to an audio") : NSLocalizedString(@"Watch %@", @"Suggested invocation phrase to watch a video");
            userActivity.suggestedInvocationPhrase = [NSString stringWithFormat:suggestedInvocationPhraseFormat, mainChapterMedia.channel.title];
        }
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
    
    UIImage *closeButtonImage = (media.mediaType == SRGMediaTypeAudio || AVAudioSession.srg_isAirPlayActive || ApplicationSettingBackgroundVideoPlaybackEnabled()) ? [UIImage imageNamed:@"arrow_down-large"] : [UIImage imageNamed:@"close-large"];
    [self.closeButton setImage:closeButtonImage forState:UIControlStateNormal];
    
    self.relatedContentsTitleLabel.font = [SRGFont fontWithStyle:SRGFontStyleH3];
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
        
        self.relatedContentsSpacerView.hidden = NO;
        [self.relatedContentsStackView play_setHidden:NO];
    }
    else {
        self.relatedContentsSpacerView.hidden = YES;
        [self.relatedContentsStackView play_setHidden:YES];
    }
    
    [self updateWatchLaterStatus];
}

// Details panel reloading
- (void)reloadDetailsWithMedia:(SRGMedia *)media mainChapterMedia:(SRGMedia *)mainChapterMedia
{
    SRGMedia *mainMedia = mainChapterMedia ?: media;
    if (mainMedia.contentType == SRGContentTypeLivestream) {
        self.scrollView.hidden = YES;
        self.channelView.hidden = NO;
        
        self.livestreamView.hidden = [self isLivestreamButtonHidden];
        
        SRGChannel *channel = mainMedia.channel;
        if ([channel.uid isEqualToString:mainMedia.uid]) {
            [self.livestreamButton setTitle:NSLocalizedString(@"Choose a regional radio", @"Title displayed on the regional radio selection button") forState:UIControlStateNormal];
        }
        else {
            [self.livestreamButton setTitle:mainMedia.title forState:UIControlStateNormal];
        }
        
        if (! self.letterboxView.fullScreen && mainChapterMedia.mediaType == SRGMediaTypeAudio) {
            [self addSongPanelWithChannel:channel];
        }
        
        self.livestreamButton.titleLabel.font = [SRGFont fontWithStyle:SRGFontStyleBody];
    }
    else {
        self.scrollView.hidden = NO;
        self.channelView.hidden = YES;
        
        [self.availabilityLabel play_displayAvailabilityLabelForMediaMetadata:mainChapterMedia];
        
        self.titleLabel.font = [SRGFont fontWithStyle:SRGFontStyleH2];
        self.titleLabel.text = media.title;
        
        self.dateLabel.font = [SRGFont fontWithStyle:SRGFontStyleSubtitle1];
        if (media.date) {
            self.dateLabel.text = [NSDateFormatter.play_relativeDateAndTimeFormatter stringFromDate:media.date].play_localizedUppercaseFirstLetterString;
            self.dateLabel.accessibilityLabel = PlayAccessibilityRelativeDateAndTimeFromDate(media.date);
        }
        else {
            self.dateLabel.text = nil;
            self.dateLabel.accessibilityLabel = nil;
        }
        
        [self removeSongPanel];
        
        self.viewCountLabel.font = [SRGFont fontWithStyle:SRGFontStyleSubtitle1];
        
        NSPredicate *socialViewsPredicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGSocialCount.new, type), @(SRGSocialCountTypeSRGView)];
        SRGSocialCount *socialCount = [media.socialCounts filteredArrayUsingPredicate:socialViewsPredicate].firstObject;
        if (socialCount && socialCount.value >= ApplicationConfiguration.sharedApplicationConfiguration.minimumSocialViewCount) {
            NSString *viewCountString = [NSNumberFormatter localizedStringFromNumber:@(socialCount.value) numberStyle:NSNumberFormatterDecimalStyle];
            if (media.mediaType == SRGMediaTypeAudio) {
                self.viewCountLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%@ listenings", @"Label displaying the number of listenings on the player"), viewCountString];
                self.viewCountLabel.accessibilityLabel = [NSString stringWithFormat:PlaySRGAccessibilityLocalizedString(@"%@ listenings", @"Label displaying the number of listenings on the player"), viewCountString];
                self.viewCountImageView.image = [UIImage imageNamed:@"view_count_audio"];
            }
            else {
                self.viewCountLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%@ views", @"Label displaying the number of views on the player"), viewCountString];
                self.viewCountLabel.accessibilityLabel = [NSString stringWithFormat:PlaySRGAccessibilityLocalizedString(@"%@ views", @"Label displaying the number of views on the player"), viewCountString];
                self.viewCountImageView.image = [UIImage imageNamed:@"view_count_video"];
            }
            self.viewCountImageView.hidden = NO;
            self.viewCountLabel.hidden = NO;
        }
        else {
            self.viewCountImageView.hidden = YES;
            self.viewCountLabel.hidden = YES;
        }
        
        [self reloadDetailsWithShow:media.show];
        
        SRGResource *resource = self.letterboxController.resource;
#if defined(DEBUG) || defined(NIGHTLY) || defined(BETA)
        // Display 🔒 in the title if the stream is protected with a DRM.
        if (resource.DRMs.count > 0) {
            self.titleLabel.text = (self.titleLabel.text != nil) ? [@"🔒 " stringByAppendingString:self.titleLabel.text] : @"🔒";
        }
#endif
        
        self.summaryLabel.font = [SRGFont fontWithStyle:SRGFontStyleBody];
        self.summaryLabel.text = media.play_fullSummary;
        
        BOOL downloaded = [Download downloadForMedia:mainChapterMedia].state == DownloadStateDownloaded;
        BOOL isWebFirst = mainChapterMedia.play_webFirst;
        BOOL hasSubtitles = resource.play_subtitlesAvailable && ! downloaded;
        BOOL hasAudioDescription = resource.play_audioDescriptionAvailable && ! downloaded;
        BOOL hasMultiAudio = resource.play_multiAudioAvailable && ! downloaded;
        if (isWebFirst || hasSubtitles || hasAudioDescription || hasMultiAudio) {
            [self.propertiesStackView play_setHidden:NO];
            self.propertiesTopLineSpacerView.hidden = NO;
            
            self.webFirstLabel.hidden = ! isWebFirst;
            self.subtitlesImageView.hidden = ! hasSubtitles;
            self.audioDescriptionImageView.hidden = ! hasAudioDescription;
            self.multiAudioImageView.hidden = ! hasMultiAudio;
        }
        else {
            [self.propertiesStackView play_setHidden:YES];
            self.propertiesTopLineSpacerView.hidden = YES;
        }
        
        [self.webFirstLabel play_setWebFirstBadge];
        
        [self updateRadioHomeButton];
        self.radioHomeButton.titleLabel.font = [SRGFont fontWithStyle:SRGFontStyleBody];
        
        UIImage *youthProtectionColorImage = YouthProtectionImageForColor(media.youthProtectionColor);
        if (youthProtectionColorImage) {
            self.youthProtectionColorImageView.image = YouthProtectionImageForColor(media.youthProtectionColor);
            self.youthProtectionColorLabel.font = [SRGFont fontWithStyle:SRGFontStyleSubtitle1];
            self.youthProtectionColorLabel.text = SRGMessageForYouthProtectionColor(media.youthProtectionColor);
            self.youthProtectionColorSpacerView.hidden = NO;
            [self.youthProtectionColorStackView play_setHidden:NO];
        }
        else {
            self.youthProtectionColorImageView.image = nil;
            self.youthProtectionColorLabel.text = nil;
            self.youthProtectionColorSpacerView.hidden = YES;
            [self.youthProtectionColorStackView play_setHidden:YES];
        }
        
        NSString *imageCopyright = media.imageCopyright;
        if (imageCopyright) {
            self.imageCopyrightLabel.font = [SRGFont fontWithStyle:SRGFontStyleSubtitle1];
            self.imageCopyrightLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Image credit: %@", @"Image copyright introductory label"), imageCopyright];
            self.imageCopyrightSpacerView.hidden = NO;
        }
        else {
            self.imageCopyrightLabel.text = nil;
            self.imageCopyrightSpacerView.hidden = YES;
        }
    }
    
    [self updateDownloadStatusForMedia:mainChapterMedia];
    [self updateWatchLaterStatusForMedia:mainChapterMedia];
    [self updateSharingStatusForMedia:mainChapterMedia];
}

- (void)reloadDetailsWithShow:(SRGShow *)show
{
    if (show) {
        [self.showThumbnailImageView play_requestImageForObject:show withScale:ImageScaleSmall type:SRGImageTypeDefault placeholder:ImagePlaceholderMediaList unavailabilityHandler:nil];
        
        self.showLabel.font = [SRGFont fontWithStyle:SRGFontStyleBody];
        self.showLabel.text = show.title;
        
        self.numberOfEpisodesLabel.font = [SRGFont fontWithStyle:SRGFontStyleSubtitle1];
        
        NSNumber *numberOfEpisodes = show.numberOfEpisodes;
        if (numberOfEpisodes) {
            NSString *numberOfEpisodesString = [NSNumberFormatter localizedStringFromNumber:numberOfEpisodes numberStyle:NSNumberFormatterDecimalStyle];
            self.numberOfEpisodesLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%@ episodes", @"The amount of episodes available for a show"), numberOfEpisodesString];
        }
        else {
            self.numberOfEpisodesLabel.text = nil;
        }
        
        [self updateFavoriteStatusForShow:show];
        
        [self.showStackView play_setHidden:NO];
    }
    else {
        [self.showStackView play_setHidden:YES];
    }
}

#pragma mark Programs

- (void)reloadCurrentProgramBackgroundAnimated:(BOOL)animated
{
    NSString *channelUid = [self channelUid];
    Channel *channel = [[ApplicationConfiguration sharedApplicationConfiguration] channelForUid:channelUid];
    
    if (self.letterboxController.live) {
        [self.currentProgramView updateWithStartColor:channel.color atPoint:CGPointMake(0.25f, 0.5f)
                                             endColor:channel.secondColor atPoint:CGPointMake(0.75f, 0.5f)
                                             animated:animated];
    }
    else {
        [self.currentProgramView updateWithStartColor:channel.color atPoint:CGPointMake(0.25f, 0.5f)
                                             endColor:channel.color atPoint:CGPointMake(0.75f, 0.5f)
                                             animated:animated];
    }
}

- (void)reloadProgramInformationAnimated:(BOOL)animated
{
    [self reloadCurrentProgramBackgroundAnimated:animated];
    
    NSString *channelUid = [self channelUid];
    Channel *channel = [[ApplicationConfiguration sharedApplicationConfiguration] channelForUid:channelUid];
    
    UIColor *foregroundColor = channel.titleColor;
    self.currentProgramMoreEpisodesButton.tintColor = foregroundColor;
    self.currentProgramTitleLabel.textColor = foregroundColor;
    self.currentProgramSubtitleLabel.textColor = foregroundColor;
    self.currentProgramFavoriteButton.tintColor = foregroundColor;
    
    self.currentProgramTitleLabel.font = [SRGFont fontWithStyle:SRGFontStyleH3];
    self.currentProgramSubtitleLabel.font = [SRGFont fontWithStyle:SRGFontStyleSubtitle1];
    
    SRGProgram *currentProgram = [self currentProgram];
    if (currentProgram) {
        self.currentProgramTitleLabel.text = currentProgram.show.title ?: currentProgram.title;
        self.currentProgramSubtitleLabel.text = [NSString stringWithFormat:@"%@ - %@", [NSDateFormatter.play_timeFormatter stringFromDate:currentProgram.startDate], [NSDateFormatter.play_timeFormatter stringFromDate:currentProgram.endDate]];
        
        BOOL hidden = (currentProgram.show == nil);
        self.currentProgramMoreEpisodesButton.hidden = hidden;
        self.currentProgramFavoriteButton.hidden = hidden;
        
        [self updateFavoriteStatusForShow:currentProgram.show];
    }
    else {
        self.currentProgramTitleLabel.text = channel.name ?: [self mainMedia].title;
        self.currentProgramSubtitleLabel.text = nil;
        
        self.currentProgramMoreEpisodesButton.hidden = YES;
        self.currentProgramFavoriteButton.hidden = YES;
        
        [self updateFavoriteStatusForShow:nil];
    }
    
    BOOL hadPrograms = (self.programs.count != 0);
    self.programs = [self updatedPrograms];
    
    [self.programsTableView reloadData];
    [self updateSelectionForCurrentProgram];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (! hadPrograms && self.programs.count != 0) {
            [self.programsTableView flashScrollIndicators];
        }
    });
}

- (NSArray<SRGProgram *> *)updatedPrograms
{
    NSDateInterval *dateInterval = self.letterboxController.play_dateInterval;
    if (! dateInterval) {
        return @[];
    }
    
    NSString *keyPath = [NSString stringWithFormat:@"@distinctUnionOfObjects.%@", @keypath(SRGSegment.new, URN)];
    NSArray<NSString *> *mediaURNs = [self.letterboxController.mediaComposition.mainChapter.segments valueForKeyPath:keyPath] ?: @[];
    
    NSDate *fromDate = (dateInterval.duration != 0.) ? dateInterval.startDate : nil;
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGProgram.new, startDate) ascending:NO];
    return [[self.programComposition play_programsFromDate:fromDate toDate:nil withMediaURNs:mediaURNs] sortedArrayUsingDescriptors:@[sortDescriptor]];
}

#pragma mark Channel updates

- (void)registerForChannelUpdates
{
    SRGMedia *mainMedia = [self mainMedia];
    if (! mainMedia) {
        return;
    }
    
    if (mainMedia.contentType != SRGContentTypeLivestream || ! mainMedia.channel) {
        return;
    }
    
    [ChannelService.sharedService removeObserver:self.channelObserver];
    self.channelObserver = [ChannelService.sharedService addObserverForUpdatesWithChannel:mainMedia.channel livestreamUid:mainMedia.uid block:^(SRGProgramComposition * _Nullable programComposition) {
        self.programComposition = programComposition;
        [self reloadProgramInformationAnimated:YES];
    }];
    [self reloadProgramInformationAnimated:NO];
}

- (void)unregisterChannelUpdates
{
    [ChannelService.sharedService removeObserver:self.channelObserver];
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
    
    UILayoutPriority priority = fullScreen ? MediaPlayerBottomConstraintFullScreenPriority : MediaPlayerBottomConstraintNormalPriority;
    self.playerTopConstraint.priority = priority;
    self.playerBottomConstraint.priority = priority;
    
    // Force metadata panel to a height of 0
    self.metadataHeightConstraint.active = fullScreen;
}

- (void)hidePlayerUserInterfaceAnimated:(BOOL)animated
{
    if (self.letterboxView.userInterfaceTogglable
            && ! UIAccessibilityIsVoiceOverRunning()
            && self.letterboxController.playbackState != SRGMediaPlayerPlaybackStatePaused
            && self.letterboxController.playbackState != SRGMediaPlayerPlaybackStateEnded) {
        [self.letterboxView setUserInterfaceHidden:YES animated:animated];
    }
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
        
        self.detailsButton.transform = CGAffineTransformMakeRotation(M_PI);
    }
    // Change to collapsed mode (set high priority for height restriction)
    else {
        self.collapsedDetailsLabelsHeightConstraint.priority = MediaPlayerDetailsLabelNormalPriority;
        
        // Use small value so that the arrow always rotates in the inverse direction
        self.detailsButton.transform = CGAffineTransformMakeRotation(0.00001);
    }
}

- (void)updateDetailsAppearance
{
    // No need for a details button if not necessary or if the expanded version is only slightly taller than the collapsed one.
    BOOL isDetailsButtonHidden = NO;
    if (self.summaryLabel.text) {
        CGFloat summaryLabelHeight = self.summaryLabel.intrinsicContentSize.height;
        if (summaryLabelHeight / MediaPlayerDetailsLabelCollapsedHeight <= MediaPlayerDetailsLabelExpansionThresholdFactor) {
            self.detailsButton.hidden = YES;
            self.detailsGestureRecognizer.enabled = NO;
            isDetailsButtonHidden = YES;
            
            self.detailsAvailable = NO;
            self.collapsedDetailsLabelsHeightConstraint.constant = summaryLabelHeight;
        }
        else {
            self.detailsAvailable = YES;
            self.collapsedDetailsLabelsHeightConstraint.constant = MediaPlayerDetailsLabelCollapsedHeight;
            
            self.detailsButton.hidden = NO;
            self.detailsGestureRecognizer.enabled = YES;
        }
    }
    else {
        self.detailsAvailable = NO;
        self.collapsedDetailsLabelsHeightConstraint.constant = 0.f;
        
        self.detailsButton.hidden = YES;
        self.detailsGestureRecognizer.enabled = NO;
        isDetailsButtonHidden = YES;
    }
    
    self.detailsButton.hidden = isDetailsButtonHidden || UIAccessibilityIsVoiceOverRunning();
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

- (SRGMedia *)mainMedia
{
    if (self.letterboxController.mediaComposition) {
        return [self.letterboxController.mediaComposition mediaForSubdivision:self.letterboxController.mediaComposition.mainChapter];
    }
    else {
        return self.letterboxController.media;
    }
}

- (SRGShow *)mainShow
{
    SRGMedia *mainChapterMedia = [self mainChapterMedia];
    if (mainChapterMedia.contentType == SRGContentTypeLivestream) {
        return [self currentProgram].show;
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
        self.shareButton.hidden = ([ApplicationConfiguration.sharedApplicationConfiguration sharingURLForMedia:media atTime:kCMTimeZero] == nil);
    }
}

- (void)updateWatchLaterStatus
{
    [self updateWatchLaterStatusForMedia:[self mainChapterMedia]];
}

- (void)updateWatchLaterStatusForMedia:(SRGMedia *)media
{
    WatchLaterAction action = WatchLaterAllowedActionForMediaMetadata(media);
    if (action == WatchLaterActionNone || self.letterboxController.continuousPlaybackUpcomingMedia || ! media) {
        self.watchLaterButton.hidden = YES;
        return;
    }
    
    self.watchLaterButton.hidden = NO;
    
    if (action == WatchLaterActionRemove) {
        [self.watchLaterButton setImage:[UIImage imageNamed:@"watch_later_full-large"] forState:UIControlStateNormal];
        self.watchLaterButton.accessibilityLabel = PlaySRGAccessibilityLocalizedString(@"Delete from \"Later\" list", @"Media deletion from later list label");
    }
    else {
        [self.watchLaterButton setImage:[UIImage imageNamed:@"watch_later-large"] forState:UIControlStateNormal];
        self.watchLaterButton.accessibilityLabel = (media.mediaType == SRGMediaTypeAudio) ? PlaySRGAccessibilityLocalizedString(@"Listen later", @"Media addition for an audio to later list label") : PlaySRGAccessibilityLocalizedString(@"Watch later", @"Media addition for a video to later list label");
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
    switch (download.state) {
        case DownloadStateAdded:
        case DownloadStateDownloadingSuspended:{
            [self.downloadButton.imageView stopAnimating];
            [self.downloadButton setImage:[UIImage imageNamed:@"downloadable_stop-large"] forState:UIControlStateNormal];
            self.downloadButton.accessibilityLabel = PlaySRGAccessibilityLocalizedString(@"Retry download", @"A download button label");
            break;
        }
            
        case DownloadStateDownloading: {
            [self.downloadButton.imageView play_setLargeDownloadAnimationWithTintColor:UIColor.whiteColor];
            [self.downloadButton.imageView startAnimating];
            
            self.downloadButton.accessibilityLabel = PlaySRGAccessibilityLocalizedString(@"Stop downloading", @"A download button label");
            break;
        }
            
        case DownloadStateDownloaded: {
            [self.downloadButton.imageView stopAnimating];
            [self.downloadButton setImage:[UIImage imageNamed:@"downloadable_full-large"] forState:UIControlStateNormal];
            self.downloadButton.accessibilityLabel = PlaySRGAccessibilityLocalizedString(@"Delete download", @"A download button label");
            break;
        }
            
        default: {
            [self.downloadButton.imageView stopAnimating];
            [self.downloadButton setImage:[UIImage imageNamed:@"downloadable-large"] forState:UIControlStateNormal];
            self.downloadButton.accessibilityLabel = PlaySRGAccessibilityLocalizedString(@"Download", @"A download button label");
            break;
        }
    }
}

- (void)updateFavoriteStatusForShow:(SRGShow *)show
{
    BOOL isFavorite = FavoritesContainsShow(show);
    UIImage *image = isFavorite ? [UIImage imageNamed:@"favorite_full"] : [UIImage imageNamed:@"favorite"];
    [self.favoriteButton setImage:image forState:UIControlStateNormal];
    [self.currentProgramFavoriteButton setImage:image forState:UIControlStateNormal];
    
    NSString *accessibilityLabel = isFavorite ? PlaySRGAccessibilityLocalizedString(@"Delete from favorites", @"Favorite label in the player view when a show has been favorited") : PlaySRGAccessibilityLocalizedString(@"Add to favorites", @"Favorite label in the player view when a show can be favorited");
    self.favoriteButton.accessibilityLabel = accessibilityLabel;
    self.currentProgramFavoriteButton.accessibilityLabel = accessibilityLabel;
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

- (void)updateTimelineVisibilityForFullScreen:(BOOL)fullScreen animated:(BOOL)animated
{
    SRGMedia *media = [self mainMedia];
    BOOL hidden = (media.contentType == SRGContentTypeLivestream && ! fullScreen);
    [self.letterboxView setTimelineAlwaysHidden:hidden animated:animated];
}

- (BOOL)isLivestreamButtonHidden
{
    SRGMedia *media = [self mainMedia];
    return ! media || ! [self.livestreamMedias containsObject:media] || self.livestreamMedias.count < 2;
}

- (void)updateLivestreamButton
{
    SRGMedia *media = [self mainMedia];
    
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
    NSString *channelUid = [self channelUid];
    RadioChannel *radioChannel = [[ApplicationConfiguration sharedApplicationConfiguration] radioChannelForUid:channelUid];
    
    self.radioHomeView.hidden = (radioChannel == nil);
    self.radioHomeButtonImageView.image = RadioChannelLogoImage(radioChannel);
    self.radioHomeButton.titleEdgeInsets = UIEdgeInsetsMake(0.f, self.radioHomeButtonImageView.image.size.width + 2 * 10.f, 0.f, 10.f);
    
    // Avoid ugly animation when setting the title, see https://stackoverflow.com/a/22101732/760435
    [UIView performWithoutAnimation:^{
        [self.radioHomeButton setTitle:[NSString stringWithFormat:NSLocalizedString(@"%@ overview", @"Title displayed on the radio home button"), radioChannel.name] forState:UIControlStateNormal];
        [self.radioHomeButton layoutIfNeeded];
    }];
}

#pragma mar Program list

- (SRGProgram *)currentProgram
{
    NSString *subdivisionURN = self.letterboxController.subdivision.URN;
    if (subdivisionURN) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGProgram.new, mediaURN), subdivisionURN];
        SRGProgram *program = [self.programComposition.programs filteredArrayUsingPredicate:predicate].firstObject;
        if (program) {
            return program;
        }
    }
    return nil;
}

- (NSIndexPath *)indexPathForProgramWithMediaURN:(NSString *)mediaURN
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGProgram.new, mediaURN), mediaURN];
    SRGProgram *program = [self.programs filteredArrayUsingPredicate:predicate].firstObject;
    if (! program) {
        return nil;
    }
    
    NSUInteger index = [self.programs indexOfObject:program];
    return [NSIndexPath indexPathForRow:index inSection:0];
}

- (NSIndexPath *)nearestProgramIndexPathForDate:(NSDate *)date
{
    if (self.programs.count == 0) {
        return nil;
    }
    
    // Consider programs from the oldest to the newest one
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGProgram.new, startDate) ascending:YES];
    NSArray<SRGProgram *> *programs = [self.programs sortedArrayUsingDescriptors:@[sortDescriptor]];
    
    // Find the nearest item in the list
    __block NSUInteger nearestIndex = 0;
    [programs enumerateObjectsUsingBlock:^(SRGProgram * _Nonnull program, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([date compare:program.startDate] == NSOrderedAscending) {
            nearestIndex = (idx > 0) ? idx - 1 : 0;
            *stop = YES;
        }
        else {
            nearestIndex = idx;
        }
    }];
    
    SRGProgram *nearestProgram = programs[nearestIndex];
    return [self indexPathForProgramWithMediaURN:nearestProgram.mediaURN];
}

- (void)scrollToProgramWithMediaURN:(NSString *)mediaURN date:(NSDate *)date animated:(BOOL)animated
{
    if (self.programsTableView.dragging) {
        return;
    }
    
    if (! mediaURN) {
        return;
    }
    
    void (^animations)(void) = ^{
        NSIndexPath *indexPath = [self indexPathForProgramWithMediaURN:mediaURN];
        if (! indexPath && date) {
            indexPath = [self nearestProgramIndexPathForDate:date];
        }
        
        if (indexPath) {
            @try {
                [self.programsTableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionNone animated:NO];
            }
            @catch (NSException *exception) {}
        }
    };
    
    if (animated) {
        [self.view layoutIfNeeded];
        [UIView animateWithDuration:0.2 animations:^{
            animations();
            [self.view layoutIfNeeded];
        }];
    }
    else {
        animations();
    }
}

- (void)scrollToNearestProgramAnimated:(BOOL)animated
{
    SRGSubdivision *subdivision = self.letterboxController.subdivision;
    [self scrollToProgramWithMediaURN:subdivision.URN date:self.letterboxController.currentDate animated:animated];
}

- (void)updateSelectionForProgramWithMediaURN:(NSString *)mediaURN
{
    NSIndexPath *indexPath = mediaURN ? [self indexPathForProgramWithMediaURN:mediaURN] : nil;
    if (indexPath) {
        [self.programsTableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
    }
    else {
        NSIndexPath *indexPath = self.programsTableView.indexPathForSelectedRow;
        if (indexPath){
            [self.programsTableView deselectRowAtIndexPath:indexPath animated:NO];
        }
    }
}

- (void)updateSelectionForCurrentProgram
{
    SRGSubdivision *subdivision = self.letterboxController.subdivision;
    [self updateSelectionForProgramWithMediaURN:subdivision.URN];
}

- (void)updateProgramProgressWithMediaURN:(NSString *)mediaURN date:(NSDate *)date
{
    NSDateInterval *dateInterval = self.letterboxController.play_dateInterval;
    for (ProgramTableViewCell *cell in self.programsTableView.visibleCells) {
        [cell updateProgressForMediaURN:mediaURN date:date dateInterval:dateInterval];
    }
}

#pragma mark Song list

- (void)scrollToNearestSongAnimated:(BOOL)animated
{
    [self scrollToSongAt:self.letterboxController.currentDate animated:animated];
}

#pragma mark SRGAnalyticsViewTracking protocol

- (NSString *)srg_pageViewTitle
{
    return AnalyticsPageTitlePlayer;
}

- (NSArray<NSString *> *)srg_pageViewLevels
{
    return @[ AnalyticsPageLevelPlay ];
}

- (BOOL)srg_isOpenedFromPushNotification
{
    return self.fromPushNotification;
}

#pragma mark SRGLetterboxViewDelegate protocol

- (void)letterboxViewWillAnimateUserInterface:(SRGLetterboxView *)letterboxView
{
    [self.view layoutIfNeeded];
    [letterboxView animateAlongsideUserInterfaceWithAnimations:^(BOOL hidden, BOOL minimal, CGFloat aspectRatio, CGFloat heightOffset) {
        self.topBarView.alpha = (minimal || ! hidden) ? 1.f : 0.f;
        
        // Calculate the minimum possible aspect ratio so that only a fraction of the vertical height is occupied by the player at most.
        // Use it as limit value if needed. Apply a smaller value to for radio (image less important, more space for metadata, especially
        // when displaying a program list).
        SRGMedia *mainMedia = [self mainMedia];
        CGFloat verticalFillRatio = (mainMedia.mediaType == SRGMediaPlayerMediaTypeVideo) ? 0.5f : 0.4f;
        CGFloat minAspectRatio = CGRectGetWidth(self.view.frame) / (verticalFillRatio * CGRectGetHeight(self.view.frame));
        CGFloat multiplier = 1.f / fmaxf(aspectRatio, minAspectRatio);
        
        self.playerAspectRatioConstraint = [self.playerAspectRatioConstraint srg_replacementConstraintWithMultiplier:multiplier constant:heightOffset];
        
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        [self setNeedsUpdateOfHomeIndicatorAutoHidden];
    }];
}

- (void)letterboxView:(SRGLetterboxView *)letterboxView toggleFullScreen:(BOOL)fullScreen animated:(BOOL)animated withCompletionHandler:(nonnull void (^)(BOOL))completionHandler
{
    void (^rotate)(UIInterfaceOrientation) = ^(UIInterfaceOrientation orientation) {
        // We interrupt the rotation attempt and trigger a rotation (which itself will toggle the expected full-screen display)
        completionHandler(NO);
        
        // User interface orientations are a subset of device orientations with matching values
        [UIDevice.currentDevice setValue:@(orientation) forKey:@keypath(UIDevice.new, orientation)];
    };
    
    // On iPhones, full-screen transitions can be triggered by rotation. In such cases, when tapping on the full-screen button,
    // we force a rotation, which itself will perform the appropriate transition from or to full-screen
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone && ! self.transitioning) {
        if (UIInterfaceOrientationIsLandscape(UIApplication.sharedApplication.delegate.window.windowScene.interfaceOrientation)) {
            rotate(UIInterfaceOrientationPortrait);
            return;
        }
        else {
            // Only force rotation from portrait to landscape orientation if the content is better watched in landscape orientation
            if (letterboxView.aspectRatio > 1.f) {
                rotate(s_previouslyUsedLandscapeInterfaceOrientation);
                return;
            }
        }
    }
    
    // Status bar is NOT updated after rotation consistently, so we must store the desired status bar visibility once
    // we have reliable information to determine it. On iPhone in landscape orientation it is always hidden since iOS 13,
    // in which case we must not hide it to avoid incorrect safe area insets after returning from landscape orientation.
    self.statusBarHidden = fullScreen && (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad || UIInterfaceOrientationIsPortrait(UIApplication.sharedApplication.delegate.window.windowScene.interfaceOrientation));
    
    void (^animations)(void) = ^{
        [self setFullScreen:fullScreen];
        [self updateTimelineVisibilityForFullScreen:fullScreen animated:NO];
        [self updateSongPanelFor:self.traitCollection fullScreen:fullScreen];
        [self setNeedsStatusBarAppearanceUpdate];
        
        if (fullScreen) {
            [self hidePlayerUserInterfaceAnimated:NO];
        }
    };
    
    void (^completion)(BOOL) = ^(BOOL finished) {
        [self setNeedsUpdateOfHomeIndicatorAutoHidden];
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

- (void)letterboxView:(SRGLetterboxView *)letterboxView didScrollWithSubdivision:(SRGSubdivision *)subdivision time:(CMTime)time date:(NSDate *)date interactive:(BOOL)interactive
{
    if (interactive) {
        SRGMedia *media = subdivision ? [self.letterboxController.mediaComposition mediaForSubdivision:subdivision] : self.letterboxController.fullLengthMedia;
        [self reloadDataOverriddenWithMedia:media mainChapterMedia:[self mainChapterMedia]];
        
        [self scrollToProgramWithMediaURN:subdivision.URN date:date animated:YES];
        [self scrollToSongAt:date animated:YES];
    }
    
    [self reloadCurrentProgramBackgroundAnimated:YES];
    
    [self updateSelectionForProgramWithMediaURN:subdivision.URN];
    [self updateSelectionForSongAt:date];
    
    [self updateProgramProgressWithMediaURN:subdivision.URN date:date];
    [self updateSongProgress];
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
    Playlist *playlist = [controller.playlistDataSource isKindOfClass:Playlist.class] ? (Playlist *)controller.playlistDataSource : nil;
    labels.extraValue1 = playlist.recommendationUid;
    [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleContinuousPlayback labels:labels];
}

- (void)letterboxView:(SRGLetterboxView *)letterboxView didCancelContinuousPlaybackWithUpcomingMedia:(SRGMedia *)upcomingMedia
{
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
    Playlist *playlist = [controller.playlistDataSource isKindOfClass:Playlist.class] ? (Playlist *)controller.playlistDataSource : nil;
    labels.extraValue1 = playlist.recommendationUid;
    [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleContinuousPlayback labels:labels];
}

- (void)letterboxView:(SRGLetterboxView *)letterboxView didLongPressSubdivision:(SRGSubdivision *)subdivision
{
    if ([self mainMedia].contentType == SRGContentTypeLivestream) {
        return;
    }
        
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
    [self play_dismissViewControllerAnimated:YES completion:nil];
    return YES;
}

- (BOOL)letterboxShouldRestoreUserInterfaceForPictureInPicture
{
    // Present the media player view controller again if needed
    UIViewController *topViewController = UIApplication.sharedApplication.delegate.window.play_topViewController;
    return ! [topViewController isKindOfClass:MediaPlayerViewController.class];
}

- (void)letterboxRestoreUserInterfaceForPictureInPictureWithCompletionHandler:(void (^)(BOOL))completionHandler
{
    UIViewController *topViewController = UIApplication.sharedApplication.delegate.window.play_topViewController;
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

- (void)letterboxDidStopPlaybackFromPictureInPicture
{
    if (! ApplicationSettingBackgroundVideoPlaybackEnabled()) {
        [SRGLetterboxService.sharedService disableForController:self.letterboxController];
    }
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

#pragma mark UITableViewDataSource protocol

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.programs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [tableView dequeueReusableCellWithIdentifier:NSStringFromClass(ProgramTableViewCell.class) forIndexPath:indexPath];
}

#pragma mark UITableViewDelegate protocol

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 55.f + LayoutMargin;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(ProgramTableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    SRGProgram *program = self.programs[indexPath.row];
    SRGLetterboxController *letterboxController = self.letterboxController;
    BOOL playing = (letterboxController.playbackState == SRGMediaPlayerPlaybackStatePlaying);
    [cell setProgram:program mediaType:letterboxController.mediaComposition.mainChapter.mediaType playing:playing];
    [cell updateProgressForMediaURN:letterboxController.subdivision.URN
                               date:letterboxController.currentDate
                       dateInterval:letterboxController.play_dateInterval];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    SRGProgram *program = self.programs[indexPath.row];
    if ([NSDate.date compare:program.startDate] == NSOrderedAscending) {
        return;
    }
    [self.letterboxController switchToURN:program.mediaURN withCompletionHandler:nil];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return (self.programs.count != 0) ? 62.f : 0.f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (self.programs.count != 0) {
        ProgramHeaderView *headerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:NSStringFromClass(ProgramHeaderView.class)];
        headerView.title = NSLocalizedString(@"Shows", @"Program list header in livestream view");
        return headerView;
    }
    else {
        return nil;
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

#pragma mark Keyboard shortcuts

- (NSArray<UIKeyCommand *> *)keyCommands
{
    NSMutableArray<UIKeyCommand *> *keyCommands = [NSMutableArray array];
    
    UIKeyCommand *togglePlayPauseCommand = [UIKeyCommand keyCommandWithInput:@" "
                                                               modifierFlags:0
                                                                      action:@selector(togglePlayPause:)];
    togglePlayPauseCommand.discoverabilityTitle = (self.letterboxController.resource.streamType == SRGMediaPlayerStreamTypeLive) ? NSLocalizedString(@"Play / Stop", @"Play / Stop shortcut label") : NSLocalizedString(@"Play / Pause", @"Play / Pause shortcut label");
    [keyCommands addObject:togglePlayPauseCommand];
    
    UIKeyCommand *toggleFullScreenCommand = [UIKeyCommand keyCommandWithInput:@"f"
                                                                modifierFlags:0
                                                                       action:@selector(toggleFullScreen:)];
    toggleFullScreenCommand.discoverabilityTitle = NSLocalizedString(@"Full screen", @"Full screen shortcut label");
    [keyCommands addObject:toggleFullScreenCommand];
    
    UIKeyCommand *exitFullScreenCommand = [UIKeyCommand keyCommandWithInput:UIKeyInputEscape
                                                              modifierFlags:0
                                                                     action:@selector(exitFullScreen:)];
    [keyCommands addObject:exitFullScreenCommand];
    
    if ([self.letterboxController canSkipWithInterval:SRGLetterboxForwardSkipInterval]) {
        UIKeyCommand *skipForwardCommand = [UIKeyCommand keyCommandWithInput:UIKeyInputRightArrow
                                                               modifierFlags:0
                                                                      action:@selector(skipForward:)];
        skipForwardCommand.discoverabilityTitle = [NSString stringWithFormat:NSLocalizedString(@"%@ forward", @"Seek forward shortcut label"),
                                                    [MediaPlayerViewControllerSkipIntervalAccessibilityFormatter() stringFromTimeInterval:SRGLetterboxForwardSkipInterval]];
        [keyCommands addObject:skipForwardCommand];
    }
    
    if ([self.letterboxController canSkipWithInterval:-SRGLetterboxBackwardSkipInterval]) {
        UIKeyCommand *skipBackwardCommand = [UIKeyCommand keyCommandWithInput:UIKeyInputLeftArrow
                                                                modifierFlags:0
                                                                       action:@selector(skipBackward:)];
        skipBackwardCommand.discoverabilityTitle = [NSString stringWithFormat:NSLocalizedString(@"%@ backward", @"Seek backward shortcut label"),
                                                   [MediaPlayerViewControllerSkipIntervalAccessibilityFormatter() stringFromTimeInterval:SRGLetterboxBackwardSkipInterval]];
        
        [keyCommands addObject:skipBackwardCommand];
    }
    
    if ([self.letterboxController canSkipToLive]) {
        UIKeyCommand *skipToLiveCommand = [UIKeyCommand keyCommandWithInput:UIKeyInputRightArrow
                                                              modifierFlags:UIKeyModifierCommand
                                                                     action:@selector(skipToLive:)];
        skipToLiveCommand.discoverabilityTitle = NSLocalizedString(@"Back to live", @"Back to live shortcut label");
        [keyCommands addObject:skipToLiveCommand];
    }
    
    if ([self.letterboxController canStartOver]) {
        UIKeyCommand *startOverCommand = [UIKeyCommand keyCommandWithInput:UIKeyInputLeftArrow
                                                             modifierFlags:UIKeyModifierCommand
                                                                    action:@selector(startOver:)];
        startOverCommand.discoverabilityTitle = NSLocalizedString(@"Start over", @"Start over shortcut label");
        [keyCommands addObject:startOverCommand];
    }
    
    return keyCommands.copy;
}

- (void)togglePlayPause:(UIKeyCommand *)command
{
    [self.letterboxController togglePlayPause];
}

- (void)toggleFullScreen:(UIKeyCommand *)command
{
    [self.letterboxView setFullScreen:! self.letterboxView.fullScreen animated:YES];
}

- (void)exitFullScreen:(UIKeyCommand *)command
{
    [self.letterboxView setFullScreen:NO animated:YES];
}

- (void)skipForward:(UIKeyCommand *)command
{
    [self.letterboxController skipWithInterval:SRGLetterboxForwardSkipInterval completionHandler:nil];
}

- (void)skipBackward:(UIKeyCommand *)command
{
    [self.letterboxController skipWithInterval:-SRGLetterboxBackwardSkipInterval completionHandler:nil];
}

- (void)skipToLive:(UIKeyCommand *)command
{
    [self.letterboxController skipToLiveWithCompletionHandler:nil];
}

- (void)startOver:(UIKeyCommand *)command
{
    [self.letterboxController startOverWithCompletionHandler:nil];
}

#pragma mark Actions

- (IBAction)toggleWatchLater:(id)sender
{
    SRGMedia *mainChapterMedia = [self mainChapterMedia];
    if (! mainChapterMedia) {
        return;
    }
    
    WatchLaterToggleMediaMetadata(mainChapterMedia, ^(BOOL added, NSError * _Nullable error) {
        if (! error) {
            AnalyticsTitle analyticsTitle = added ? AnalyticsTitleWatchLaterAdd : AnalyticsTitleWatchLaterRemove;
            SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
            labels.source = AnalyticsSourceButton;
            labels.value = mainChapterMedia.URN;
            [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:analyticsTitle labels:labels];
            
            [Banner showWatchLaterAdded:added forItemWithName:mainChapterMedia.title inViewController:self];
        }
    });
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
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Delete download", @"Title of the confirmation pop-up displayed when the user is about to delete a download")
                                                                                 message:NSLocalizedString(@"The downloaded content will be deleted.", @"Confirmation message displayed when the user is about to delete a download")
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
    
    Float64 currentPosition = 0;
    SRGMedia *segmentMedia = nil;
    
    if (mainMedia.contentType != SRGContentTypeLivestream && mainMedia.contentType != SRGContentTypeScheduledLivestream) {
        CMTime time = self.letterboxController.currentTime;
        if (CMTIME_IS_VALID(time)
                && CMTimeGetSeconds(time) >= 1.
                && self.letterboxController.playbackState != SRGMediaPlayerPlaybackStateIdle
                && self.letterboxController.playbackState != SRGMediaPlayerPlaybackStatePreparing
                && self.letterboxController.playbackState != SRGMediaPlayerPlaybackStateEnded) {
            currentPosition = CMTimeGetSeconds(time);
        }
        
        segmentMedia = ! [mainMedia isEqual:self.letterboxController.media] ? self.letterboxController.media : nil;
    }
    
    void (^sharingCompletionBlock)(SharingItem *, NSString *) = ^(SharingItem *sharingItem, NSString *URN) {
        UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithSharingItem:sharingItem source:AnalyticsSourceButton inViewController:self withCompletionBlock:^(UIActivityType  _Nonnull activityType) {
            SRGSubdivision *subdivision = [self.letterboxController.mediaComposition subdivisionWithURN:URN];
            if (subdivision.event) {
                [[SRGDataProvider.currentDataProvider play_increaseSocialCountForActivityType:activityType URN:subdivision.URN event:subdivision.event withCompletionBlock:^(SRGSocialCountOverview * _Nullable socialCountOverview, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
                    // Nothing
                }] resume];
            }
        }];
        activityViewController.modalPresentationStyle = UIModalPresentationPopover;
        
        UIPopoverPresentationController *popoverPresentationController = activityViewController.popoverPresentationController;
        popoverPresentationController.sourceView = sender;
        popoverPresentationController.sourceRect = [sender bounds];
        
        [self presentViewController:activityViewController animated:YES completion:nil];
    };
    
    if (currentPosition != 0. || segmentMedia) {
        NSString *message = mainMedia.title;
        if (mainMedia.show.title && ! [mainMedia.title containsString:mainMedia.show.title]) {
            message = [NSString stringWithFormat:@"%@ ─ %@", mainMedia.show.title, mainMedia.title];
        }
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Share", @"Title of the action view to choose a sharing action") message:message preferredStyle:UIAlertControllerStyleActionSheet];
        
        if (segmentMedia) {
            [alertController addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"\"%@\"", segmentMedia.title] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                SharingItem *sharingItem = [SharingItem sharingItemForCurrentClip:segmentMedia];
                sharingCompletionBlock(sharingItem, segmentMedia.URN);
            }]];
        }
        
        NSString *mainTitle = (mainMedia.contentType == SRGContentTypeEpisode) ? NSLocalizedString(@"The entire episode", @"Button label to share the entire episode being played.") : NSLocalizedString(@"The content", @"Button label to share the content being played.");
        [alertController addAction:[UIAlertAction actionWithTitle:mainTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            SharingItem *sharingItem = [SharingItem sharingItemForMedia:mainMedia atTime:kCMTimeZero];
            sharingCompletionBlock(sharingItem, mainMedia.URN);
        }]];
        
        if (currentPosition != 0.) {
            NSString *positionTitleFormat = (mainMedia.contentType == SRGContentTypeEpisode) ? NSLocalizedString(@"The episode at %@", @"Button label to share the entire episode being played at time (hours / minutes / seconds).") : NSLocalizedString(@"The content at %@", @"Button label to share the content being played at time (hours / minutes / seconds).");
            [alertController addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:positionTitleFormat, PlayHumanReadableFormattedDuration(currentPosition)] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                SharingItem *sharingItem = [SharingItem sharingItemForMedia:mainMedia atTime:CMTimeMakeWithSeconds(currentPosition, NSEC_PER_SEC)];
                sharingCompletionBlock(sharingItem, mainMedia.URN);
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
        SharingItem *sharingItem = [SharingItem sharingItemForMedia:mainMedia atTime:kCMTimeZero];
        sharingCompletionBlock(sharingItem, mainMedia.URN);
    }
}

- (IBAction)toggleDetails:(id)sender
{
    [self setDetailsExpanded:! self.detailsExpanded animated:YES];
}

- (IBAction)openShow:(id)sender
{
    SRGShow *show = [self mainShow];
    if (! show) {
        return;
    }
    
    NSString *channelUid = [self channelUid];
    RadioChannel *radioChannel = [[ApplicationConfiguration sharedApplicationConfiguration] radioChannelForUid:channelUid];
    
    ApplicationSectionInfo *applicationSectionInfo = [ApplicationSectionInfo applicationSectionInfoWithApplicationSection:ApplicationSectionOverview radioChannel:radioChannel];
    PlayAppDelegate *appDelegate = (PlayAppDelegate *)UIApplication.sharedApplication.delegate;
    [appDelegate.rootTabBarController openApplicationSectionInfo:applicationSectionInfo];
    
    SectionViewController *showViewController = [SectionViewController showViewControllerFor:show];
    [appDelegate.rootTabBarController pushViewController:showViewController animated:NO];
    [appDelegate.window play_dismissAllViewControllersAnimated:YES completion:nil];
}

- (IBAction)openRadioHome:(id)sender
{
    NSString *channelUid = [self channelUid];
    RadioChannel *radioChannel = [[ApplicationConfiguration sharedApplicationConfiguration] radioChannelForUid:channelUid];
    if (! radioChannel) {
        return;
    }
    
    ApplicationSectionInfo *applicationSectionInfo = [ApplicationSectionInfo applicationSectionInfoWithApplicationSection:ApplicationSectionOverview radioChannel:radioChannel];
    
    PlayAppDelegate *appDelegate = (PlayAppDelegate *)UIApplication.sharedApplication.delegate;
    [appDelegate.rootTabBarController openApplicationSectionInfo:applicationSectionInfo];
    [appDelegate.window play_dismissAllViewControllersAnimated:YES completion:nil];
}

- (IBAction)toggleFavorite:(id)sender
{
    SRGShow *show = [self mainShow];
    if (! show) {
        return;
    }
    
    FavoritesToggleShow(show);
    [self updateFavoriteStatusForShow:show];
    
    BOOL isFavorite = FavoritesContainsShow(show);
    
    AnalyticsTitle analyticsTitle = isFavorite ? AnalyticsTitleFavoriteAdd : AnalyticsTitleFavoriteRemove;
    SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
    labels.source = AnalyticsSourceButton;
    labels.value = show.URN;
    [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:analyticsTitle labels:labels];
    
    [Banner showFavorite:isFavorite forItemWithName:show.title inViewController:self];
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
            ApplicationSettingSetSelectedLivestreamURNForChannelUid(media.channel.uid, media.URN);
            
            // Use the playback state if playing
            SRGMediaPlayerPlaybackState currentPlaybackState = self.letterboxController.playbackState;
            if (currentPlaybackState == SRGMediaPlayerPlaybackStatePlaying) {
                [self.letterboxController playMedia:media atPosition:nil withPreferredSettings:ApplicationSettingPlaybackSettings()];
            }
            else {
                [self.letterboxController prepareToPlayMedia:media atPosition:nil withPreferredSettings:ApplicationSettingPlaybackSettings() completionHandler:nil];
            }
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
    [self play_dismissViewControllerAnimated:YES completion:nil];
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
            if ((progress <= 0.5f && velocity > 1000.f) || (progress > 0.5f && velocity > -1000.f)) {
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
    SRGMedia *media = notification.userInfo[SRGLetterboxMediaKey];
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
        
        [self unregisterChannelUpdates];
        [self registerForChannelUpdates];
    }
    
    [self reloadDataOverriddenWithMedia:nil mainChapterMedia:nil];
    [self reloadProgramInformationAnimated:YES];
    
    // When switching from video to audio or conversely, ensure the UI togglability is correct
    if (media.mediaType != previousMedia.mediaType) {
        [self setUserInterfaceBehaviorForMedia:media animated:YES];
    }
    
    [self updateTimelineVisibilityForFullScreen:self.letterboxView.fullScreen animated:YES];
    [self updateGoogleCastButton];
}

- (void)playbackStateDidChange:(NSNotification *)notification
{
    SRGMediaType mediaType = self.letterboxController.media.mediaType;
    SRGMediaPlayerPlaybackState playbackState = [notification.userInfo[SRGMediaPlayerPlaybackStateKey] integerValue];
    
    if (mediaType == SRGMediaTypeAudio && playbackState == SRGMediaPlayerPlaybackStatePlaying) {
        self.closeButton.accessibilityHint = PlaySRGAccessibilityLocalizedString(@"Closes the player and continue playing audio.", @"Player close button hint");
    }
    else if (mediaType == SRGMediaTypeVideo && AVAudioSession.srg_isAirPlayActive && playbackState == SRGMediaPlayerPlaybackStatePlaying) {
        self.closeButton.accessibilityHint = PlaySRGAccessibilityLocalizedString(@"Closes the player and continue playing video with AirPlay.", @"Player close button hint");
    }
    else if (mediaType == SRGMediaTypeVideo && ApplicationSettingBackgroundVideoPlaybackEnabled() && playbackState == SRGMediaPlayerPlaybackStatePlaying) {
        self.closeButton.accessibilityHint = PlaySRGAccessibilityLocalizedString(@"Closes the player and continue playing in the background.", @"Player close button hint");
    }
    else {
        self.closeButton.accessibilityHint = nil;
    }
    
    [self reloadProgramInformationAnimated:YES];
    [self reloadDataOverriddenWithMedia:nil mainChapterMedia:nil];
    
    SRGMediaPlayerPlaybackState previousPlaybackState = [notification.userInfo[SRGMediaPlayerPreviousPlaybackStateKey] integerValue];
    if (previousPlaybackState == SRGMediaPlayerPlaybackStateSeeking) {
        [self scrollToNearestProgramAnimated:YES];
        [self scrollToNearestSongAnimated:YES];
    }
}

- (void)playbackDidFail:(NSNotification *)notification
{
    // Let the user access the top bar in case of an error
    self.topBarView.alpha = 1.f;
    
    self.closeButton.accessibilityHint = nil;
}

- (void)segmentDidStart:(NSNotification *)notification
{
    SRGSegment *segment = notification.userInfo[SRGMediaPlayerSegmentKey];
    [self scrollToProgramWithMediaURN:segment.URN date:self.letterboxController.currentDate animated:YES];
    [self updateSelectionForProgramWithMediaURN:segment.URN];
}

- (void)segmentDidEnd:(NSNotification *)notification
{
    [self updateSelectionForProgramWithMediaURN:nil];
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    // Based on conditions just before sending the app to the background, determine whether we should consider prompting the
    // user for background video playback (this guess might change depending on how the app has been found to be sent to the
    // background, see below)
    if (! ApplicationSettingBackgroundVideoPlaybackEnabled()
            && ! self.letterboxController.pictureInPictureActive
            && self.letterboxController.media.mediaType == SRGMediaTypeVideo
            && self.letterboxController.playbackState == SRGMediaPlayerPlaybackStatePlaying) {
        self.shouldDisplayBackgroundVideoPlaybackPrompt = YES;
    }
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    if (self.shouldDisplayBackgroundVideoPlaybackPrompt) {
        // To determine whether a background entry is due to the lock screen being enabled or not, we need to wait a little bit.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // Don't prompt for backround playback if the device was simply locked
            self.displayBackgroundVideoPlaybackPrompt = ! UIDevice.play_isLocked;
        });
    }
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    // Display the prompt if this makes sense (only once)
    if (self.displayBackgroundVideoPlaybackPrompt) {
        self.displayBackgroundVideoPlaybackPrompt = NO;
        
        UIViewController *topViewController = UIApplication.sharedApplication.delegate.window.play_topViewController;
        if (topViewController != self) {
            return;
        }
        
        PlayApplicationRunOnce(^(void (^completionHandler)(BOOL success)) {
            NSUserDefaults *userDefaults = NSUserDefaults.standardUserDefaults;
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Enable background video playback?", @"Title of the alert view to opt-in for background video playback")
                                                                                     message:NSLocalizedString(@"You can manage this feature in the settings at any time.", @"Description of the alert view to opt-in for background video playback")
                                                                              preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Later", @"Label for the button for deciding to opt-in for background video playback at a later time") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                completionHandler(YES);
            }]];
            [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Enable", @"Label for the button keeping autoplay enabled") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [userDefaults setBool:YES forKey:PlaySRGSettingBackgroundVideoPlaybackEnabled];
                [userDefaults synchronize];
                self.letterboxController.backgroundVideoPlaybackEnabled = YES;
                completionHandler(YES);
            }]];
            
            [topViewController presentViewController:alertController animated:YES completion:nil];
        }, @"BackgroundVideoPlaybackAsked", nil);
    }
    self.shouldDisplayBackgroundVideoPlaybackPrompt = NO;
}

- (void)reachabilityDidChange:(NSNotification *)notification
{
    if (ReachabilityBecameReachable(notification)) {
        [self reloadDataOverriddenWithMedia:nil mainChapterMedia:nil];
        
        if (self.livestreamMedias.count == 0) {
            [self updateLivestreamButton];
        }
    }
}

- (void)playlistEntriesDidChange:(NSNotification *)notification
{
    NSString *playlistUid = notification.userInfo[SRGPlaylistUidKey];
    NSSet<NSString *> *entriesUids = notification.userInfo[SRGPlaylistEntriesUidsKey];
    if ([playlistUid isEqualToString:SRGPlaylistUidWatchLater] && [entriesUids containsObject:[self mainChapterMedia].URN]) {
        [self updateWatchLaterStatus];
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

- (void)contentSizeCategoryDidChange:(NSNotification *)notification
{
    [self reloadDataOverriddenWithMedia:nil mainChapterMedia:nil];
    [self reloadProgramInformationAnimated:NO];
}

@end
