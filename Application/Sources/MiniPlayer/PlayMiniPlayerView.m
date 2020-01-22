//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "PlayMiniPlayerView.h"

#import "ApplicationConfiguration.h"
#import "ApplicationSettings.h"
#import "Banner.h"
#import "ChannelService.h"
#import "GoogleCast.h"
#import "History.h"
#import "MediaPlayerViewController.h"
#import "NSBundle+PlaySRG.h"
#import "SRGProgram+PlaySRG.h"
#import "UIView+PlaySRG.h"
#import "UIViewController+PlaySRG.h"

#import <MAKVONotificationCenter/MAKVONotificationCenter.h>
#import <SRGAppearance/SRGAppearance.h>
#import <SRGLetterbox/SRGLetterbox.h>
#import <libextobjc/libextobjc.h>

@interface PlayMiniPlayerView ()

@property (nonatomic) SRGMedia *media;          // Latest media
@property (nonatomic) SRGChannel *channel;      // Latest channel information, if any

@property (nonatomic) SRGLetterboxController *controller;

@property (nonatomic, weak) IBOutlet UIProgressView *progressView;

// FIXME: Do not use SRGPlaybackButton! To have it work requires exposing private implementation details (see below)
//        and why this can work is difficult to understand (since a hidden action calling -togglePlayPause on the media
//        player controller exists and is used). Instead, write a Play SRG PlaybackButton. We could even think about moving
//        this class to the Letterbox framework, but this requires some team discussion first.
@property (nonatomic, weak) IBOutlet SRGPlaybackButton *playbackButton;
@property (nonatomic, weak) IBOutlet UILabel *titleLabel;

@property (nonatomic, weak) id periodicTimeObserver;

@end

@interface SRGLetterboxController (MediaPlayerController_Private)

@property (nonatomic, readonly) SRGMediaPlayerController *mediaPlayerController;

@end

@implementation PlayMiniPlayerView

#pragma mark Class methods

+ (PlayMiniPlayerView *)view
{
    static dispatch_once_t s_onceToken;
    static PlayMiniPlayerView *s_view;
    dispatch_once(&s_onceToken, ^{
        s_view = [NSBundle.mainBundle loadNibNamed:NSStringFromClass(self) owner:nil options:nil].firstObject;
    });
    return s_view;
}

#pragma mark Object lifecycle

- (void)dealloc
{
    self.controller = nil;
}

#pragma mark Getters and setters

- (void)setMedia:(SRGMedia *)media
{
    self.channel = media.channel;
    
    [self unregisterChannelUpdatesWithMedia:_media];
    _media = media;
    [self registerForChannelUpdatesWithMedia:media];
}

- (void)setController:(SRGLetterboxController *)controller
{
    if (_controller) {
        [self unregisterUserInterfaceUpdatesWithController:_controller];
        
        [NSNotificationCenter.defaultCenter removeObserver:self
                                                      name:SRGLetterboxMetadataDidChangeNotification
                                                    object:_controller];
    }
    
    _controller = controller;
    
    // Always keep the most recent media information to be able to restart at a later time
    if (controller.media) {
        self.media = controller.media;
    }
    
    [self reloadData];
    
    if (controller) {
        [self registerUserInterfaceUpdatesWithController:controller];
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(mediaMetadataDidChange:)
                                                   name:SRGLetterboxMetadataDidChangeNotification
                                                 object:controller];
    }
}

#pragma mark Overrides

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.titleLabel.text = nil;
    
    self.progressView.progress = 0.f;
    self.progressView.progressTintColor = UIColor.redColor;
    
    self.backgroundColor = UIColor.clearColor;
    
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openFullScreenPlayer:)];
    [self addGestureRecognizer:tapGestureRecognizer];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(applicationDidEnterBackground:)
                                               name:UIApplicationDidEnterBackgroundNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(applicationWillEnterForeground:)
                                               name:UIApplicationWillEnterForegroundNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(contentSizeCategoryDidChange:)
                                               name:UIContentSizeCategoryDidChangeNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(audioSessionRouteDidChange:)
                                               name:AVAudioSessionRouteChangeNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(googleCastPlaybackDidStart:)
                                               name:GoogleCastPlaybackDidStartNotification
                                             object:nil];
}

- (void)willMoveToWindow:(UIWindow *)newWindow
{
    [super willMoveToWindow:newWindow];
    
    SRGLetterboxService *letterboxService = SRGLetterboxService.sharedService;
    
    if (newWindow) {
        // Track service controller changes and tracks the corresponding controller (UI updates will only be triggered
        // when the controller plays audio, though)
        @weakify(self)
        @weakify(letterboxService)
        [letterboxService addObserver:self keyPath:@keypath(letterboxService.controller) options:0 block:^(MAKVONotification *notification) {
            @strongify(self)
            @strongify(letterboxService)
            
            self.controller = letterboxService.controller;
        }];
        self.controller = letterboxService.controller;
        
        [self reloadData];
        
        [self registerForChannelUpdatesWithMedia:self.media];
    }
    else {
        [letterboxService removeObserver:self keyPath:@keypath(letterboxService.controller)];
        self.controller = nil;
        
        [self unregisterChannelUpdatesWithMedia:self.media];
    }
}

#pragma mark Accessibility

- (BOOL)isAccessibilityElement
{
    return YES;
}

- (UIAccessibilityTraits)accessibilityTraits
{
    // Treat as header for quick navigation to the mini player
    return UIAccessibilityTraitHeader;
}

- (NSString *)accessibilityLabel
{
    if (! self.media) {
        return nil;
    }
    
    NSString *format = (self.controller.playbackState == SRGMediaPlayerPlaybackStatePlaying) ? PlaySRGAccessibilityLocalizedString(@"Now playing: %@", @"Mini player label") : PlaySRGAccessibilityLocalizedString(@"Recently played: %@", @"Mini player label");
    
    if (self.media.contentType == SRGContentTypeLivestream) {
        NSMutableString *accessibilityLabel = [NSMutableString stringWithFormat:format, self.channel.title];
        SRGProgram *currentProgram = self.channel.currentProgram;
        
        NSDate *currentDate = self.controller.date;
        if (currentProgram && (! currentDate || [currentProgram play_containsDate:currentDate])) {
            [accessibilityLabel appendFormat:@", %@", currentProgram.title];
        }
        return accessibilityLabel.copy;
    }
    else {
        NSMutableString *accessibilityLabel = [NSMutableString stringWithFormat:format, self.media.title];
        if (self.media.show.title && ! [self.media.title containsString:self.media.show.title]) {
            [accessibilityLabel appendFormat:@", %@", self.media.show.title];
        }
        return accessibilityLabel.copy;
    }
}

- (NSString *)accessibilityHint
{
    return PlaySRGAccessibilityLocalizedString(@"Plays the content.", @"Mini player action hint");
}

#pragma mark Data

- (void)reloadData
{
    self.titleLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleBody];
    
    SRGProgram *currentProgram = self.channel.currentProgram;
    
    // Display program information (if any) when the controller position is within the current program, otherwise channel
    // information.
    NSDate *currentDate = self.controller.date;
    if (currentProgram && (! currentDate || [currentProgram play_containsDate:currentDate])) {
        self.titleLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Currently: %@", @"Title in the mini player for the live stream, if the current program is known."), currentProgram.title];
    }
    else {
        self.titleLabel.text = self.media.title;
    }
    
    [self updateProgress];
}

- (void)updateProgress
{
    if (self.controller && [self.controller.media isEqual:self.media]) {
        CMTimeRange timeRange = self.controller.timeRange;
        CMTime currentTime = self.controller.currentTime;
        
        if (CMTIMERANGE_IS_VALID(timeRange) && ! CMTIMERANGE_IS_EMPTY(timeRange)) {
            self.progressView.progress = CMTimeGetSeconds(CMTimeSubtract(currentTime, timeRange.start)) / CMTimeGetSeconds(timeRange.duration);
            return;
        }
    }
    
    // For non-started playback, display a full progress bar for livestreams (matching the usual slider behavior starting
    // at the end)
    self.progressView.progress = (self.media.contentType == SRGContentTypeLivestream) ? 1.f : HistoryPlaybackProgressForMediaMetadata(self.media);
}

- (void)updateMetadataWithMedia:(SRGMedia *)media
{
    if (! [media isEqual:self.media]) {
        self.media = media;
    }
    // Fix for inconsistent RTS data. A media from a media list does not have a channel oject, but a media created from a
    // media composition has one. Use the one retrieved from the Letterbox metadata notification if available as fallback.
    else if (! self.channel && media.channel) {
        self.media = media;
    }
    
    [self reloadData];
}

#pragma mark Controller registration for playback-related UI updates

- (void)registerUserInterfaceUpdatesWithController:(SRGLetterboxController *)controller
{
    self.playbackButton.mediaPlayerController = controller.mediaPlayerController;
    
    @weakify(self)
    self.periodicTimeObserver = [controller addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1., NSEC_PER_SEC) queue:NULL usingBlock:^(CMTime time) {
        @strongify(self)
        [self reloadData];
    }];
    [self reloadData];
}

- (void)unregisterUserInterfaceUpdatesWithController:(SRGLetterboxController *)controller
{
    self.playbackButton.mediaPlayerController = nil;
    [controller removePeriodicTimeObserver:self.periodicTimeObserver];
}

#pragma mark Channel updates

- (void)registerForChannelUpdatesWithMedia:(SRGMedia *)media
{
    if (! media) {
        return;
    }
    
    if (media.contentType != SRGContentTypeLivestream) {
        return;
    }
    
    [ChannelService.sharedService registerObserver:self forChannelUpdatesWithMedia:media block:^(SRGChannel * _Nullable channel) {
        self.channel = channel;
        [self reloadData];
    }];
}

- (void)unregisterChannelUpdatesWithMedia:(SRGMedia *)media
{
    if (! media) {
        return;
    }
    
    [ChannelService.sharedService unregisterObserver:self forMedia:media];
}

#pragma mark Actions

// The button is an `SRGPlaybackButton` which automatically toggles play / pause
- (IBAction)togglePlaybackButton:(id)sender
{
    if (! self.media) {
        return;
    }
    
    // If a controller is readily available, use it
    SRGMedia *media = self.media;
    SRGPosition *position = HistoryResumePlaybackPositionForMedia(media);
    SRGLetterboxController *controller = self.controller;
    
    // If a controller is readily available, use it
    if (controller) {
        [controller playMedia:media atPosition:position withPreferredSettings:ApplicationSettingPlaybackSettings()];
    }
    // Otherwise use a fresh instance and enable it with the service. The mini player observes service controller changes
    // and will automatically be updated
    else {
        controller = [[SRGLetterboxController alloc] init];
        ApplicationConfigurationApplyControllerSettings(controller);
        [controller playMedia:media atPosition:position withPreferredSettings:ApplicationSettingPlaybackSettings()];
        [SRGLetterboxService.sharedService enableWithController:controller pictureInPictureDelegate:nil];
    }
    
    if (media.mediaType == SRGMediaTypeVideo && ! ApplicationSettingBackgroundVideoPlaybackEnabled() && ! AVAudioSession.srg_isAirPlayActive) {
        [self.nearestViewController play_presentMediaPlayerFromLetterboxController:controller withAirPlaySuggestions:YES fromPushNotification:NO animated:YES completion:nil];
    }
}

- (IBAction)close:(id)sender
{
    [SRGLetterboxService.sharedService disableForController:self.controller];
    [self.controller reset];
    
    self.media = nil;
}

#pragma mark Gestures

- (void)openFullScreenPlayer:(UIGestureRecognizer *)gestureRecognizer
{
    SRGMedia *media = self.media;
    if (! media) {
        return;
    }
    
    SRGLetterboxController *controller = self.controller;
    if ([controller.media isEqual:media]) {
        [self.nearestViewController play_presentMediaPlayerFromLetterboxController:controller withAirPlaySuggestions:YES fromPushNotification:NO animated:YES completion:nil];
    }
    else {
        [self.nearestViewController play_presentMediaPlayerWithMedia:media position:nil airPlaySuggestions:YES fromPushNotification:NO animated:YES completion:nil];
    }
}

#pragma mark Notifications

- (void)mediaMetadataDidChange:(NSNotification *)notification
{
    SRGMedia *media = notification.userInfo[SRGLetterboxMediaKey];
    [self updateMetadataWithMedia:media];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    [self unregisterUserInterfaceUpdatesWithController:self.controller];
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    [self registerUserInterfaceUpdatesWithController:self.controller];
}

- (void)contentSizeCategoryDidChange:(NSNotification *)notification
{
    [self reloadData];
}

- (void)audioSessionRouteDidChange:(NSNotification *)notification
{
    // Called on a background thread!
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.media.mediaType == SRGMediaTypeVideo && ! AVAudioSession.srg_isAirPlayActive) {
            [self.controller stop];
        }
    });
}

- (void)googleCastPlaybackDidStart:(NSNotification *)notification
{
    SRGMedia *media = notification.userInfo[GoogleCastMediaKey];
    [self updateMetadataWithMedia:media];
}

@end
