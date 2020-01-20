//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "ShowViewController.h"

#import "ActivityItemSource.h"
#import "ApplicationConfiguration.h"
#import "Banner.h"
#import "MediaCollectionViewCell.h"
#import "Favorites.h"
#import "NSBundle+PlaySRG.h"
#import "PlayAppDelegate.h"
#import "ShowHeaderView.h"
#import "UIApplication+PlaySRG.h"
#import "UIColor+PlaySRG.h"
#import "UIViewController+PlaySRG.h"

#import <libextobjc/libextobjc.h>
#import <SRGAppearance/SRGAppearance.h>

@interface ShowViewController ()

@property (nonatomic) SRGShow *show;

@property (nonatomic, getter=isFromPushNotification) BOOL fromPushNotification;

@end

@implementation ShowViewController

#pragma mark Object lifecycle

- (instancetype)initWithShow:(SRGShow *)show fromPushNotification:(BOOL)fromPushNotification
{
    if (self = [super init]) {
        self.show = show;
        self.fromPushNotification = fromPushNotification;
    }
    return self;
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = UIColor.play_blackColor;
    
    NSURL *sharingURL = [ApplicationConfiguration.sharedApplicationConfiguration sharingURLForShow:self.show];
    if (sharingURL) {
        UIBarButtonItem *shareButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"share-22"]
                                                                            style:UIBarButtonItemStylePlain
                                                                           target:self
                                                                           action:@selector(shareContent:)];
        shareButtonItem.accessibilityLabel = PlaySRGAccessibilityLocalizedString(@"Share", @"Share button label on player view");
        self.navigationItem.rightBarButtonItems = @[ shareButtonItem ];
    }
    
    self.collectionView.backgroundColor = UIColor.clearColor;
    self.collectionView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    self.collectionView.alwaysBounceVertical = YES;
    
    NSString *headerIdentifier = NSStringFromClass(ShowHeaderView.class);
    UINib *headerNib = [UINib nibWithNibName:headerIdentifier bundle:nil];
    [self.collectionView registerNib:headerNib forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:headerIdentifier];
    
    [self updateAppearanceForSize:self.view.frame.size];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(accessibilityVoiceOverStatusChanged:)
                                               name:UIAccessibilityVoiceOverStatusChanged
                                             object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.userActivity = [[NSUserActivity alloc] initWithActivityType:[NSBundle.mainBundle.bundleIdentifier stringByAppendingString:@".displaying"]];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    self.userActivity = nil;
    
    self.fromPushNotification = NO;
}

#pragma mark Rotation

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return [super supportedInterfaceOrientations] & UIViewController.play_supportedInterfaceOrientations;
}

#pragma mark Responsiveness

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> _Nonnull context) {
        [self.collectionView.collectionViewLayout invalidateLayout];
        [self updateAppearanceForSize:size];
        
        ShowHeaderView *headerView = (ShowHeaderView *)[self.collectionView supplementaryViewForElementKind:UICollectionElementKindSectionHeader atIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        if (headerView) {
            [headerView updateAspectRatioWithSize:self.collectionView.frame.size];
        }
    } completion:nil];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    
    [self.collectionView.collectionViewLayout invalidateLayout];
    ShowHeaderView *headerView = (ShowHeaderView *)[self.collectionView supplementaryViewForElementKind:UICollectionElementKindSectionHeader atIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    if (headerView) {
        [headerView updateAspectRatioWithSize:self.collectionView.frame.size];
    }
    
    [self updateAppearanceForSize:self.view.frame.size];
}

#pragma mark Status bar

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

#pragma mark Overrides

- (void)prepareRefreshWithRequestQueue:(SRGRequestQueue *)requestQueue page:(SRGPage *)page completionHandler:(ListRequestPageCompletionHandler)completionHandler
{
    SRGPaginatedEpisodeCompositionCompletionBlock completionBlock = ^(SRGEpisodeComposition * _Nullable episodeComposition, SRGPage * _Nonnull page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@ || %K == %@", @keypath(SRGMedia.new, contentType), @(SRGContentTypeEpisode), @keypath(SRGMedia.new, contentType), @(SRGContentTypeScheduledLivestream)];
        
        NSMutableArray *medias = [NSMutableArray array];
        for (SRGEpisode *episode in episodeComposition.episodes) {
            NSArray *mediasForEpisode = [episode.medias filteredArrayUsingPredicate:predicate];
            [medias addObjectsFromArray:mediasForEpisode];
        }
        
        if (episodeComposition.show) {
            self.show = episodeComposition.show;
            
            [self updateAppearanceForSize:self.view.frame.size];
        }
        
        completionHandler(medias.copy, page, nextPage, HTTPResponse, error);
    };
    
    NSUInteger pageSize = ApplicationConfiguration.sharedApplicationConfiguration.pageSize;
    
    SRGPageRequest *request = [[[SRGDataProvider.currentDataProvider latestEpisodesForShowWithURN:self.show.URN maximumPublicationDay:nil completionBlock:completionBlock] requestWithPageSize:pageSize] requestWithPage:page];
    [requestQueue addRequest:request resume:YES];
}

- (AnalyticsPageType)pageType
{
    if (self.show.transmission == SRGTransmissionRadio) {
        return AnalyticsPageTypeRadio;
    }
    else if (self.show.transmission == SRGTransmissionOnline) {
        return AnalyticsPageTypeOnline;
    }
    else {
        return AnalyticsPageTypeTV;
    }
}

- (NSString *)srg_pageViewTitle
{
    // Since we sometimes reset the view controller title for display purposes, we need to reliably return the show title
    // as page title
    return self.show.title;
}

#pragma mark Peek and pop

- (NSArray<id<UIPreviewActionItem>> *)previewActionItems
{
    NSMutableArray<id<UIPreviewActionItem>> *previewActionItems = [NSMutableArray array];
    
    BOOL isFavorite = FavoritesContainsShow(self.show);
    
    UIPreviewAction *favoriteAction = [UIPreviewAction actionWithTitle:isFavorite ? NSLocalizedString(@"Remove from favorites", @"Button label to remove a show from favorites in the show preview window") : NSLocalizedString(@"Add to favorites", @"Button label to add a show to favorites in the show preview window") style:isFavorite ? UIPreviewActionStyleDestructive : UIPreviewActionStyleDefault handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
        FavoritesToggleShow(self.show);
        
        // Use !isFavorite since favorite status has been reversed
        AnalyticsTitle analyticsTitle = (! isFavorite) ? AnalyticsTitleFavoriteAdd : AnalyticsTitleFavoriteRemove;
        SRGAnalyticsHiddenEventLabels *labels = [[SRGAnalyticsHiddenEventLabels alloc] init];
        labels.source = AnalyticsSourcePeekMenu;
        labels.value = self.show.URN;
        [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:analyticsTitle labels:labels];
        
        [Banner showFavorite:! isFavorite forItemWithName:self.show.title inViewController:nil /* Not 'self' since dismissed */];
    }];
    [previewActionItems addObject:favoriteAction];    
    
    NSURL *sharingURL = [ApplicationConfiguration.sharedApplicationConfiguration sharingURLForShow:self.show];
    if (sharingURL) {
        UIPreviewAction *shareAction = [UIPreviewAction actionWithTitle:NSLocalizedString(@"Share", @"Button label of the sharing choice in the show preview window") style:UIPreviewActionStyleDefault handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
            ActivityItemSource *activityItemSource = [[ActivityItemSource alloc] initWithShow:self.show URL:sharingURL];
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
                labels.value = self.show.URN;
                [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleSharingShow labels:labels];
                
                if ([activityType isEqualToString:UIActivityTypeCopyToPasteboard]) {
                    [Banner showWithStyle:BannerStyleInfo
                                  message:NSLocalizedString(@"The content has been copied to the clipboard.", @"Message displayed when some content (media, show, etc.) has been copied to the clipboard")
                                    image:nil
                                   sticky:NO
                         inViewController:nil /* Not 'self' since dismissed */];
                }
            };
            
            activityViewController.modalPresentationStyle = UIModalPresentationPopover;
            
            UIViewController *viewController = self.play_previewingContext.sourceView.nearestViewController;
            [viewController presentViewController:activityViewController animated:YES completion:nil];
        }];
        [previewActionItems addObject:shareAction];
    }
    
    UIPreviewAction *openAction = [UIPreviewAction actionWithTitle:NSLocalizedString(@"Open", @"Button label to open a show from the preview window") style:UIPreviewActionStyleDefault handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
        ShowViewController *showViewController = [[ShowViewController alloc] initWithShow:self.show fromPushNotification:NO];
        
        UIViewController *viewController = self.play_previewingContext.sourceView.nearestViewController;
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
    [previewActionItems addObject:openAction];
    
    return previewActionItems.copy;
}

#pragma mark UIResponder (ActivityContinuation)

- (void)updateUserActivityState:(NSUserActivity *)userActivity
{
    [super updateUserActivityState:userActivity];
    
    userActivity.title = self.show.title;
    [userActivity addUserInfoEntriesFromDictionary:@{ @"URNString" : self.show.URN,
                                                      @"SRGShowData" : [NSKeyedArchiver archivedDataWithRootObject:self.show],
                                                      @"applicationVersion" : [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] }];
    userActivity.webpageURL = [ApplicationConfiguration.sharedApplicationConfiguration sharingURLForShow:self.show];
}

#pragma mark UI

- (void)updateAppearanceForSize:(CGSize)size
{
    // Display the title and an empty image when the show header is not visible (so that the view never feels empty, and
    // so that the show title can be read)
    if ([ShowHeaderView heightForShow:self.show withSize:size] == 0.f) {
        self.title = self.show.title;
        self.emptyCollectionImage = [UIImage imageNamed:@"media-90"];
    }
    else {
        self.title = UIAccessibilityIsVoiceOverRunning() ? self.show.title : nil;
        self.emptyCollectionImage = nil;
    }
    
    NSString *broadcastInformationMessage = self.show.broadcastInformation.message;
    if (broadcastInformationMessage) {
        self.emptyCollectionTitle = broadcastInformationMessage;
        self.emptyCollectionSubtitle = @"";
    }
    else {
        self.emptyCollectionTitle = nil;
        self.emptyCollectionSubtitle = nil;
    }
    
    [self.collectionView reloadEmptyDataSet];
}

#pragma mark Actions

- (IBAction)shareContent:(UIBarButtonItem *)barButtonItem
{
    if (! self.show) {
        return;
    }
    
    NSURL *sharingURL = [ApplicationConfiguration.sharedApplicationConfiguration sharingURLForShow:self.show];
    if (! sharingURL) {
        return;
    }
    
    ActivityItemSource *activityItemSource = [[ActivityItemSource alloc] initWithShow:self.show URL:sharingURL];
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
        labels.source = AnalyticsSourceButton;
        labels.value = self.show.URN;
        [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleSharingShow labels:labels];
        
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
    UIView *barButtonItemView = [barButtonItem valueForKey:@"view"];
    if (barButtonItemView) {
        popoverPresentationController.sourceView = barButtonItemView;
        popoverPresentationController.sourceRect = barButtonItemView.bounds;
    }
    
    [self presentViewController:activityViewController animated:YES completion:nil];
}

#pragma mark DZNEmptyDataSetSource protocol

- (CGFloat)verticalOffsetForEmptyDataSet:(UIScrollView *)scrollView
{
    CGFloat offset = [super verticalOffsetForEmptyDataSet:scrollView];
    return offset + [ShowHeaderView heightForShow:self.show withSize:scrollView.frame.size] / 2.f;
}

- (NSAttributedString *)buttonTitleForEmptyDataSet:(UIScrollView *)scrollView forState:(UIControlState)state
{
    if (self.show.broadcastInformation.URL) {
        NSDictionary *attributes = @{ NSFontAttributeName : [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleTitle],
                                      NSForegroundColorAttributeName : UIColor.whiteColor };
        return [[NSAttributedString alloc] initWithString:NSLocalizedString(@"Show more", @"Show more button label when a link is available for broadcast information.") attributes:attributes];
    }
    else {
        return nil;
    }
}

#pragma mark DZNEmptyDataSetDelegate protocol

- (void)emptyDataSet:(UIScrollView *)scrollView didTapButton:(UIButton *)button
{
    NSURL *broadcastInformationURL = self.show.broadcastInformation.URL;
    if (broadcastInformationURL) {
        [UIApplication.sharedApplication play_openURL:broadcastInformationURL withCompletionHandler:nil];
    }
}

#pragma mark UICollectionViewDataSource protocol

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    if ([kind isEqualToString:UICollectionElementKindSectionHeader]) {
        ShowHeaderView *headerView = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:NSStringFromClass(ShowHeaderView.class) forIndexPath:indexPath];
        [headerView updateAspectRatioWithSize:collectionView.frame.size];
        return headerView;
    }
    else {
        return [super collectionView:collectionView viewForSupplementaryElementOfKind:kind atIndexPath:indexPath];
    }
}

#pragma mark UICollectionViewDelegateFlowLayout protocol

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
    CGSize size = collectionView.frame.size;
    return CGSizeMake(size.width, [ShowHeaderView heightForShow:self.show withSize:size]);
}

#pragma mark UICollectionViewDelegate protocol

- (void)collectionView:(UICollectionView *)collectionView willDisplaySupplementaryView:(UICollectionReusableView *)view forElementKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
    if ([view isKindOfClass:ShowHeaderView.class]) {
        ShowHeaderView *headerView = (ShowHeaderView *)view;
        headerView.show = self.show;
        
        // iOS 11 bug: The header hides scroll indicators
        // See https://stackoverflow.com/questions/46747960/ios11-uicollectionsectionheader-clipping-scroll-indicator
        if (@available(iOS 11, *)) {
            headerView.layer.zPosition = 0;
        }
    }
}

#pragma mark Notifications

- (void)accessibilityVoiceOverStatusChanged:(NSNotification *)notification
{
    [self updateAppearanceForSize:self.view.frame.size];
    [self.collectionView reloadData];
}

#pragma mark SRGAnalyticsViewTracking protocol

- (BOOL)srg_isOpenedFromPushNotification
{
    return self.fromPushNotification;
}

@end
