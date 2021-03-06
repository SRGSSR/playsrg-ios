//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "MediaPreviewViewController.h"

#import "ActivityItemSource.h"
#import "AnalyticsConstants.h"
#import "ApplicationConfiguration.h"
#import "ApplicationSettings.h"
#import "Banner.h"
#import "ChannelService.h"
#import "Download.h"
#import "GoogleCast.h"
#import "History.h"
#import "MediaPlayerViewController.h"
#import "NSDateFormatter+PlaySRG.h"
#import "PlayAppDelegate.h"
#import "PlayErrors.h"
#import "ShowViewController.h"
#import "SRGDataProvider+PlaySRG.h"
#import "SRGMedia+PlaySRG.h"
#import "SRGMediaComposition+PlaySRG.h"
#import "SRGProgramComposition+PlaySRG.h"
#import "UIImageView+PlaySRG.h"
#import "UIStackView+PlaySRG.h"
#import "UIView+PlaySRG.h"
#import "UIViewController+PlaySRG.h"
#import "UIWindow+PlaySRG.h"
#import "WatchLater.h"

@import SRGAnalyticsDataProvider;
@import SRGAppearance;
@import SRGMediaPlayer;

@interface MediaPreviewViewController ()

@property (nonatomic) SRGMedia *media;
@property (nonatomic) SRGProgramComposition *programComposition;

@property (nonatomic) IBOutlet SRGLetterboxController *letterboxController;      // top object, strong
@property (nonatomic, weak) IBOutlet SRGLetterboxView *letterboxView;

@property (nonatomic, weak) IBOutlet UILabel *titleLabel;

@property (nonatomic, weak) IBOutlet UIStackView *mediaInfoStackView;
@property (nonatomic, weak) IBOutlet UILabel *showLabel;
@property (nonatomic, weak) IBOutlet UILabel *summaryLabel;

@property (nonatomic, weak) IBOutlet UIStackView *channelInfoStackView;
@property (nonatomic, weak) IBOutlet UILabel *programTimeLabel;
@property (nonatomic, weak) IBOutlet UILabel *channelLabel;

@property (nonatomic, weak) IBOutlet NSLayoutConstraint *playerAspectRatioConstraint;

@property (nonatomic) BOOL shouldRestoreServicePlayback;
@property (nonatomic, copy) NSString *previousAudioSessionCategory;

@property (nonatomic, weak) id channelObserver;

@end

@implementation MediaPreviewViewController

#pragma mark Object lifecycle

- (instancetype)initWithMedia:(SRGMedia *)media
{
    if (self = [self initFromStoryboard]) {
        self.media = media;
    }
    return self;
}

- (instancetype)initFromStoryboard
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:NSStringFromClass(self.class) bundle:nil];
    return storyboard.instantiateInitialViewController;
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Will restore playback iff a controller attached to the service was actually playing content before (ignore
    // other running playback playback states, like stalled or seeking, since such cases are not really relevant and
    // cannot be restored anyway as is)
    SRGLetterboxController *serviceController = SRGLetterboxService.sharedService.controller;
    if (serviceController.playbackState == SRGMediaPlayerPlaybackStatePlaying) {
        [serviceController pause];
        self.shouldRestoreServicePlayback = YES;
    }
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(applicationDidBecomeActive:)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(mediaMetadataDidChange:)
                                               name:SRGLetterboxMetadataDidChangeNotification
                                             object:self.letterboxController];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(contentSizeCategoryDidChange:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];
    
    self.letterboxController.contentURLOverridingBlock = ^(NSString *URN) {
        Download *download = [Download downloadForURN:URN];
        return download.localMediaFileURL;
    };
    ApplicationConfigurationApplyControllerSettings(self.letterboxController);
    
    [self.letterboxController playMedia:self.media atPosition:HistoryResumePlaybackPositionForMedia(self.media) withPreferredSettings:ApplicationSettingPlaybackSettings()];
    [self.letterboxView setUserInterfaceHidden:YES animated:NO togglable:NO];
    [self.letterboxView setTimelineAlwaysHidden:YES animated:NO];
    
    [self updateFonts];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if ([self play_isMovingToParentViewController]) {
        // Ajust preview size for better readability on phones. The default content size works fine on iPads.
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
            CGSize screenSize = UIScreen.mainScreen.bounds.size;
            BOOL isPortrait = screenSize.height > screenSize.width;
            CGFloat factor = isPortrait ? 2.5f : 1.f;
            
            CGFloat width = CGRectGetWidth(self.view.frame);
            self.preferredContentSize = CGSizeMake(width, factor * 9.f / 16.f * width);
            
            if (self.media.contentType == SRGContentTypeLivestream && self.media.channel) {
                self.channelObserver = [ChannelService.sharedService addObserverForUpdatesWithChannel:self.media.channel livestreamUid:self.media.uid block:^(SRGProgramComposition * _Nullable programComposition) {
                    self.programComposition = programComposition;
                    [self reloadData];
                }];
            }
            [self reloadData];
        }
        
        self.previousAudioSessionCategory = [AVAudioSession sharedInstance].category;
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    }
    
    if (self.letterboxController.mediaComposition) {
        [self srg_trackPageView];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    if ([self play_isMovingFromParentViewController]) {
        [ChannelService.sharedService removeObserver:self.channelObserver];
        
        // Restore playback on exit. Works well with cancelled peek, as well as with pop, without additional checks. Wait
        // a little bit since peek view dismissal occurs just before an action item has been selected. Moreover, having
        // a small delay sounds better.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.shouldRestoreServicePlayback) {
                [[AVAudioSession sharedInstance] setCategory:self.previousAudioSessionCategory error:nil];
                [SRGLetterboxService.sharedService.controller play];
            }
        });
    }
}

#pragma mark Rotation

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return [super supportedInterfaceOrientations] & UIViewController.play_supportedInterfaceOrientations;
}

#pragma mark Peek and pop

- (NSArray<id<UIPreviewActionItem>> *)previewActionItems
{
    NSMutableArray<id<UIPreviewActionItem>> *previewActionItems = [NSMutableArray array];
    
    WatchLaterAction action = WatchLaterAllowedActionForMediaMetadata(self.media);
    if (action != WatchLaterActionNone) {
        BOOL isRemoval = (action == WatchLaterActionRemove);
        NSString *addActionTitle = (self.media.mediaType == SRGMediaTypeAudio) ? NSLocalizedString(@"Listen later", @"Button label to add an audio to the later list, from the media preview window") : NSLocalizedString(@"Watch later", @"Button label to add a video to the later list, from the media preview window");
        UIPreviewAction *watchLaterAction = [UIPreviewAction actionWithTitle:isRemoval ? NSLocalizedString(@"Delete from \"Later\"", @"Button label to delete a media from the later list, from the media preview window") : addActionTitle style:isRemoval ? UIPreviewActionStyleDestructive : UIPreviewActionStyleDefault handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
            WatchLaterToggleMediaMetadata(self.media, ^(BOOL added, NSError * _Nullable error) {
                if (! error) {
                    AnalyticsTitle analyticsTitle = added ? AnalyticsTitleWatchLaterAdd : AnalyticsTitleWatchLaterRemove;
                    SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
                    labels.source = AnalyticsSourcePeekMenu;
                    labels.value = self.media.URN;
                    [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:analyticsTitle labels:labels];
                    
                    [Banner showWatchLaterAdded:added forItemWithName:self.media.title inViewController:nil /* Not 'self' since dismissed */];
                }
            });
        }];
        [previewActionItems addObject:watchLaterAction];
    }
    
    BOOL downloadable = [Download canDownloadMedia:self.media];
    if (downloadable) {
        Download *download = [Download downloadForMedia:self.media];
        BOOL downloaded = (download != nil);
        UIPreviewAction *downloadAction = [UIPreviewAction actionWithTitle:downloaded ? NSLocalizedString(@"Delete from downloads", @"Button label to delete a download from the media preview window") : NSLocalizedString(@"Add to downloads", @"Button label to add a download from the media preview window") style:downloaded ? UIPreviewActionStyleDestructive : UIPreviewActionStyleDefault handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
            if (downloaded) {
                [Download removeDownload:download];
            }
            else {
                [Download addDownloadForMedia:self.media];
            }
            
            // Use !downloaded since the status has been reversed
            AnalyticsTitle analyticsTitle = ! downloaded ? AnalyticsTitleDownloadAdd : AnalyticsTitleDownloadRemove;
            SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
            labels.source = AnalyticsSourcePeekMenu;
            labels.value = self.media.URN;
            [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:analyticsTitle labels:labels];
        }];
        [previewActionItems addObject:downloadAction];
    }
    
    NSURL *sharingURL = [ApplicationConfiguration.sharedApplicationConfiguration sharingURLForMediaMetadata:self.media atTime:kCMTimeZero];
    if (sharingURL) {
        UIPreviewAction *shareAction = [UIPreviewAction actionWithTitle:NSLocalizedString(@"Share", @"Button label of the sharing choice in the media preview window") style:UIPreviewActionStyleDefault handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
            ActivityItemSource *activityItemSource = [[ActivityItemSource alloc] initWithMedia:self.media URL:sharingURL];
            UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[ activityItemSource ] applicationActivities:nil];
            activityViewController.excludedActivityTypes = @[ UIActivityTypePrint,
                                                              UIActivityTypeAssignToContact,
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
                labels.source = AnalyticsSourcePeekMenu;
                labels.value = self.media.URN;
                labels.extraValue1 = AnalyticsTypeValueSharingContent;
                [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleSharingMedia labels:labels];
                
                SRGSubdivision *subdivision = [self.letterboxController.mediaComposition subdivisionWithURN:self.media.URN];
                if (subdivision.event) {
                    [[SRGDataProvider.currentDataProvider play_increaseSocialCountForActivityType:activityType URN:subdivision.URN event:subdivision.event withCompletionBlock:^(SRGSocialCountOverview * _Nullable socialCountOverview, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
                        // Nothing
                    }] resume];
                }
                
                if ([activityType isEqualToString:UIActivityTypeCopyToPasteboard]) {
                    [Banner showWithStyle:BannerStyleInfo
                                  message:NSLocalizedString(@"The content has been copied to the clipboard.", @"Message displayed when some content (media, show, etc.) has been copied to the clipboard")
                                    image:nil
                                   sticky:NO
                         inViewController:nil /* Not 'self' since dismissed */];
                }
            };
            
            activityViewController.modalPresentationStyle = UIModalPresentationPopover;
            
            UIViewController *viewController = self.play_previewingContext.sourceView.play_nearestViewController;
            [viewController presentViewController:activityViewController animated:YES completion:nil];
        }];
        [previewActionItems addObject:shareAction];
    }
    
    if (! ApplicationConfiguration.sharedApplicationConfiguration.moreEpisodesHidden && self.media.show) {
        UIPreviewAction *showAction = [UIPreviewAction actionWithTitle:NSLocalizedString(@"More episodes", @"Button label to open the show episode page from the preview window") style:UIPreviewActionStyleDefault handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
            ShowViewController *showViewController = [[ShowViewController alloc] initWithShow:self.media.show fromPushNotification:NO];
            
            UIViewController *viewController = self.play_previewingContext.sourceView.play_nearestViewController;
            UINavigationController *navigationController = viewController.navigationController;
            if (navigationController) {
                [navigationController pushViewController:showViewController animated:YES];
            }
            else {
                UIApplication *application = UIApplication.sharedApplication;
                PlayAppDelegate *appDelegate = (PlayAppDelegate *)application.delegate;
                [appDelegate.rootTabBarController pushViewController:showViewController animated:YES];
            }
        }];
        [previewActionItems addObject:showAction];
    }
    
    UIPreviewAction *openAction = [UIPreviewAction actionWithTitle:NSLocalizedString(@"Open", @"Button label to open a media from the start from the preview window") style:UIPreviewActionStyleDefault handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
        self.shouldRestoreServicePlayback = NO;
        
        UIView *sourceView = self.play_previewingContext.sourceView;
        [sourceView.play_nearestViewController play_presentMediaPlayerFromLetterboxController:self.letterboxController withAirPlaySuggestions:NO fromPushNotification:NO animated:YES completion:nil];
    }];
    [previewActionItems addObject:openAction];
    
    return previewActionItems.copy;
}

#pragma mark Data

- (void)reloadData
{
    SRGChannel *channel = self.programComposition.channel;
    if (channel) {
        [self.mediaInfoStackView play_setHidden:YES];
        [self.channelInfoStackView play_setHidden:NO];
        
        SRGProgram *currentProgram = [self.programComposition play_programAtDate:NSDate.date];
        if (currentProgram) {
            self.titleLabel.text = currentProgram.title;
            
            self.channelLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleSubtitle];
            self.channelLabel.text = channel.title;
            
            self.programTimeLabel.font = [UIFont srg_lightFontWithTextStyle:SRGAppearanceFontTextStyleBody];
            self.programTimeLabel.text = [NSString stringWithFormat:@"%@ - %@", [NSDateFormatter.play_timeFormatter stringFromDate:currentProgram.startDate], [NSDateFormatter.play_timeFormatter stringFromDate:currentProgram.endDate]];
        }
        else {
            self.titleLabel.text = channel.title;
            self.channelLabel.text = nil;
            self.programTimeLabel.text = nil;
        }
    }
    else {
        self.titleLabel.text = self.media.title;
        self.showLabel.text = (self.media.show.title && ! [self.media.title containsString:self.media.show.title]) ? self.media.show.title : nil;
        
        [self.mediaInfoStackView play_setHidden:NO];
        [self.channelInfoStackView play_setHidden:YES];
        
        self.summaryLabel.text = self.media.play_fullSummary;
    }
}

#pragma mark UI

- (void)updateFonts
{
    self.titleLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleTitle];
    self.showLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleBody];
    self.summaryLabel.font = [UIFont srg_regularFontWithTextStyle:SRGAppearanceFontTextStyleBody];
    
    self.programTimeLabel.font = [UIFont srg_lightFontWithTextStyle:SRGAppearanceFontTextStyleBody];
    self.channelLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleSubtitle];
}

#pragma mark SRGAnalyticsViewTracking protocol

- (NSString *)srg_pageViewTitle
{
    return AnalyticsPageTitlePlayer;
}

- (NSArray<NSString *> *)srg_pageViewLevels
{
    return @[ AnalyticsPageLevelPlay, AnalyticsPageLevelPreview ];
}

#pragma mark SRGLetterboxViewDelegate protocol

- (void)letterboxViewWillAnimateUserInterface:(SRGLetterboxView *)letterboxView
{
    [self.view layoutIfNeeded];
    [letterboxView animateAlongsideUserInterfaceWithAnimations:^(BOOL hidden, BOOL minimal, CGFloat aspecRatio, CGFloat heightOffset) {
        self.playerAspectRatioConstraint = [self.playerAspectRatioConstraint srg_replacementConstraintWithMultiplier:fminf(1.f / aspecRatio, 1.f) constant:heightOffset];
        [self.view layoutIfNeeded];
    } completion:nil];
}

#pragma mark Notifications

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    // Automatically resumes playback since we have no controls
    [self.letterboxController togglePlayPause];
}

- (void)mediaMetadataDidChange:(NSNotification *)notification
{
    [self reloadData];
    
    // Notify page view when the full-length changes.
    SRGMediaComposition *previousMediaComposition = notification.userInfo[SRGLetterboxPreviousMediaCompositionKey];
    SRGMediaComposition *mediaComposition = notification.userInfo[SRGLetterboxMediaCompositionKey];
    
    if (self.play_viewVisible && mediaComposition && ! [mediaComposition.fullLengthMedia isEqual:previousMediaComposition.fullLengthMedia]) {
        [self srg_trackPageView];
    }
}

- (void)contentSizeCategoryDidChange:(NSNotification *)notification
{
    [self updateFonts];
}

@end
