//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "ModuleViewController.h"

#import "ActivityItemSource.h"
#import "ApplicationConfiguration.h"
#import "Banner.h"
#import "MediaCollectionViewCell.h"
#import "ModuleHeaderView.h"
#import "NSBundle+PlaySRG.h"
#import "PlayAppDelegate.h"
#import "UIColor+PlaySRG.h"
#import "UIViewController+PlaySRG.h"
#import "UIWindow+PlaySRG.h"

#import <libextobjc/libextobjc.h>

@interface ModuleViewController ()

@property (nonatomic) SRGModule *module;

@end

@implementation ModuleViewController

#pragma mark Object lifecycle

- (instancetype)initWithModule:(SRGModule *)module
{
    if (self = [super init]) {
        self.module = module;
    }
    return self;
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = UIColor.play_blackColor;
    
    NSURL *sharingURL = [ApplicationConfiguration.sharedApplicationConfiguration sharingURLForModule:self.module];
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
    
    NSString *headerIdentifier = NSStringFromClass(ModuleHeaderView.class);
    UINib *headerNib = [UINib nibWithNibName:headerIdentifier bundle:nil];
    [self.collectionView registerNib:headerNib forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:headerIdentifier];
    
    [self updateAppearanceForSize:self.view.frame.size];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(accessibilityVoiceOverStatusChanged:)
                                               name:UIAccessibilityVoiceOverStatusChanged
                                             object:nil];
}

#pragma mark Rotation

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return [super supportedInterfaceOrientations] & UIViewController.play_supportedInterfaceOrientations;
}

#pragma mark Responsiveness

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self.collectionView.collectionViewLayout invalidateLayout];
        [self updateAppearanceForSize:size];
        
        ModuleHeaderView *headerView = (ModuleHeaderView *)[self.collectionView supplementaryViewForElementKind:UICollectionElementKindSectionHeader atIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        if (headerView) {
            [headerView updateAspectRatioWithSize:self.collectionView.frame.size];
        }
    } completion:nil];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    
    [self.collectionView.collectionViewLayout invalidateLayout];
    ModuleHeaderView *headerView = (ModuleHeaderView *)[self.collectionView supplementaryViewForElementKind:UICollectionElementKindSectionHeader atIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
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
    NSUInteger pageSize = ApplicationConfiguration.sharedApplicationConfiguration.pageSize;
    SRGPageRequest *request = [[[SRGDataProvider.currentDataProvider latestMediasForModuleWithURN:self.module.URN completionBlock:completionHandler] requestWithPageSize:pageSize] requestWithPage:page];
    [requestQueue addRequest:request resume:YES];
}

- (AnalyticsPageType)pageType
{
    return AnalyticsPageTypeTV;
}

- (NSString *)srg_pageViewTitle
{
    // Since we sometimes reset the view controller title for display purposes, we need to reliably return the module title
    // as page title
    return self.module.title;
}

#pragma mark Peek and pop

- (NSArray<id<UIPreviewActionItem>> *)previewActionItems
{
    NSMutableArray<id<UIPreviewActionItem>> *previewActionItems = [NSMutableArray array];
    
    NSURL *sharingURL = [ApplicationConfiguration.sharedApplicationConfiguration sharingURLForModule:self.module];
    if (sharingURL) {
        UIPreviewAction *shareAction = [UIPreviewAction actionWithTitle:NSLocalizedString(@"Share", @"Button label of the sharing choice in the module preview window") style:UIPreviewActionStyleDefault handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
            ActivityItemSource *activityItemSource = [[ActivityItemSource alloc] initWithModule:self.module URL:sharingURL];
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
                labels.value = self.module.URN;
                [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleSharingModule labels:labels];
                
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
    
    UIPreviewAction *openAction = [UIPreviewAction actionWithTitle:NSLocalizedString(@"Open", @"Button label to open a module from the preview window") style:UIPreviewActionStyleDefault handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
        UIApplication *application = UIApplication.sharedApplication;
        PlayAppDelegate *appDelegate = (PlayAppDelegate *)application.delegate;
        __kindof UIViewController *viewController = self.play_previewingContext.sourceView.nearestViewController;
        UINavigationController *navigationController = [viewController isKindOfClass:UINavigationController.class] ? viewController : appDelegate.rootTabBarController.selectedViewController;
        [navigationController pushViewController:self animated:YES];
    }];
    [previewActionItems addObject:openAction];
    
    return previewActionItems.copy;
}

#pragma mark UI

- (void)updateAppearanceForSize:(CGSize)size
{
    // Display the title and an empty image when the module header is not visible (so that the view never feels empty, and
    // so that the module title can be read)
    if ([ModuleHeaderView heightForModule:self.module withSize:size] == 0.f) {
        self.title = self.module.title;
        self.emptyCollectionImage = [UIImage imageNamed:@"media-90"];
    }
    else {
        self.title = UIAccessibilityIsVoiceOverRunning() ? self.module.title : nil;
        self.emptyCollectionImage = nil;
    }
    
    [self.collectionView reloadEmptyDataSet];
}

#pragma mark Actions

- (IBAction)shareContent:(UIBarButtonItem *)barButtonItem
{
    if (! self.module) {
        return;
    }
    
    NSURL *sharingURL = [ApplicationConfiguration.sharedApplicationConfiguration sharingURLForModule:self.module];
    if (! sharingURL) {
        return;
    }
    
    ActivityItemSource *activityItemSource = [[ActivityItemSource alloc] initWithModule:self.module URL:sharingURL];
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
        labels.value = self.module.URN;
        [SRGAnalyticsTracker.sharedTracker trackHiddenEventWithName:AnalyticsTitleSharingModule labels:labels];
        
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
    return offset + [ModuleHeaderView heightForModule:self.module withSize:scrollView.frame.size] / 2.f;
}

#pragma mark UICollectionViewDataSource protocol

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    if ([kind isEqualToString:UICollectionElementKindSectionHeader]) {
        ModuleHeaderView *headerView = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:NSStringFromClass(ModuleHeaderView.class) forIndexPath:indexPath];
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
    return CGSizeMake(size.width, [ModuleHeaderView heightForModule:self.module withSize:size]);
}

#pragma mark UICollectionViewDelegate protocol

- (void)collectionView:(UICollectionView *)collectionView willDisplaySupplementaryView:(UICollectionReusableView *)view forElementKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
    if ([view isKindOfClass:ModuleHeaderView.class]) {
        ModuleHeaderView *headerView = (ModuleHeaderView *)view;
        headerView.module = self.module;
        
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

@end
