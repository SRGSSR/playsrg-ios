//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "AnalyticsConstants.h"
#import "NSBundle+PlaySRG.h"

NSString *AnalyticsNameForPageType(AnalyticsPageType pageType)
{
    static dispatch_once_t s_onceToken;
    static NSDictionary<NSNumber *, NSString *> *s_names;
    dispatch_once(&s_onceToken, ^{
        s_names = @{ @(AnalyticsPageTypeTV) : NSLocalizedString(@"TV", @"[Technical] TV page type for analytics measurements"),
                     @(AnalyticsPageTypeRadio) : NSLocalizedString(@"Radio", @"[Technical] Radio page type for analytics measurements"),
                     @(AnalyticsPageTypeOnline) : NSLocalizedString(@"Online", @"[Technical] Online page type for analytics measurements"),
                     @(AnalyticsPageTypeSystem) : NSLocalizedString(@"System", @"[Technical] System page type for analytics measurements"),
                     @(AnalyticsPageTypeFavorites) : NSLocalizedString(@"Favorites", @"[Technical] Favorites page type for analytics measurements"),
                     @(AnalyticsPageTypeDownloads) : NSLocalizedString(@"Downloads", @"[Technical] Downloads page type for analytics measurements"),
                     @(AnalyticsPageTypeHistory) : NSLocalizedString(@"History", @"[Technical] History page type for analytics measurements"),
                     @(AnalyticsPageTypeSubscriptions) : NSLocalizedString(@"Subscriptions", @"[Technical] Subscriptions page type for analytics measurements"),
                     @(AnalyticsPageTypeNotifications) : NSLocalizedString(@"Notifications", @"[Technical] Notifications page type for analytics measurements"),
                     @(AnalyticsPageTypeSearch) : NSLocalizedString(@"Search", @"[Technical] Search page type for analytics measurements"),
                     @(AnalyticsPageTypeOnboarding) : NSLocalizedString(@"Onboarding", @"[Technical] Onboarding page type for analytics measurements"),
                     @(AnalyticsPageTypeUser) : PlaySRGNonLocalizedString(@"User"),
                     @(AnalyticsPageTypeWatchLater) : PlaySRGNonLocalizedString(@"Watch later") };
    });
    return s_names[@(pageType)];
}

AnalyticsTitle const AnalyticsTitleContinuousPlayback = @"continuous_playback";
AnalyticsTitle const AnalyticsTitleDownloadAdd = @"download";
AnalyticsTitle const AnalyticsTitleDownloadRemove = @"download_remove";
AnalyticsTitle const AnalyticsTitleDownloadRemoveAll = @"download_remove_all";
AnalyticsTitle const AnalyticsTitleDownloadOpenMedia = @"play_download";
AnalyticsTitle const AnalyticsTitleFavoriteAdd = @"favorite";
AnalyticsTitle const AnalyticsTitleFavoriteRemove = @"favorite_remove";
AnalyticsTitle const AnalyticsTitleFavoriteRemoveAll = @"favorite_remove_all";
AnalyticsTitle const AnalyticsTitleFavoriteOpenMedia = @"play_favorite";
AnalyticsTitle const AnalyticsTitleFavoriteOpenShow = @"show_favorite";
AnalyticsTitle const AnalyticsTitleGoogleCast = @"google_cast";
AnalyticsTitle const AnalyticsTitleHistoryRemove = @"history_remove";
AnalyticsTitle const AnalyticsTitleHistoryRemoveAll = @"history_remove_all";
AnalyticsTitle const AnalyticsTitleHistoryOpenMedia = @"play_history";
AnalyticsTitle const AnalyticsTitleIdentity = @"identity";
AnalyticsTitle const AnalyticsTitleNotificationOpen = @"open_notification";
AnalyticsTitle const AnalyticsTitleNotificationPushOpen = @"open_push_notification";
AnalyticsTitle const AnalyticsTitleOpenURL = @"open_url_ios";
AnalyticsTitle const AnalyticsTitlePictureInPicture = @"picture_in_picture";
AnalyticsTitle const AnalyticsTitleQuickActions = @"quick_actions_ios";
AnalyticsTitle const AnalyticsTitleSharing = @"share";
AnalyticsTitle const AnalyticsTitleSharingModule = @"share_module";
AnalyticsTitle const AnalyticsTitleSharingShow = @"share_show";
AnalyticsTitle const AnalyticsTitleSubscriptionAdd = @"subscription";
AnalyticsTitle const AnalyticsTitleSubscriptionRemove = @"subscription_remove";
AnalyticsTitle const AnalyticsTitleSubscriptionRemoveAll = @"subscription_remove_all";
AnalyticsTitle const AnalyticsTitleSubscriptionOpenShow = @"show_subscription";
AnalyticsTitle const AnalyticsTitleSearch = @"search";
AnalyticsTitle const AnalyticsTitleUserActivity = @"user_activity_ios";
AnalyticsTitle const AnalyticsTitleWatchLaterAdd = @"watch_later";
AnalyticsTitle const AnalyticsTitleWatchLaterRemove = @"watch_later_remove";
AnalyticsTitle const AnalyticsTitleWatchLaterRemoveAll = @"watch_later_remove_all";
AnalyticsTitle const AnalyticsTitleWatchLaterOpenMedia = @"play_watch_later";

AnalyticsSource const AnalyticsSourceAutomatic = @"automatic";
AnalyticsSource const AnalyticsSourceButton = @"button";
AnalyticsSource const AnalyticsSourceClose = @"close";
AnalyticsSource const AnalyticsSourceHandoff = @"handoff";
AnalyticsSource const AnalyticsSourceLongPress = @"long_click";
AnalyticsSource const AnalyticsSourceNotification = @"notification";
AnalyticsSource const AnalyticsSourceNotificationPush = @"push_notification";
AnalyticsSource const AnalyticsSourcePeekMenu = @"peek_menu";
AnalyticsSource const AnalyticsSourceSchemeURL = @"scheme_url";
AnalyticsSource const AnalyticsSourceSelection = @"selection";
AnalyticsSource const AnalyticsSourceSwipe = @"swipe";

AnalyticsType const AnalyticsTypeActionLive = @"openlive";
AnalyticsType const AnalyticsTypeActionFavorites = @"openfavorites";
AnalyticsType const AnalyticsTypeActionDownloads = @"opendownloads";
AnalyticsType const AnalyticsTypeActionHistory = @"openhistory";
AnalyticsType const AnalyticsTypeActionSearch = @"opensearch";
AnalyticsType const AnalyticsTypeActionPlayMedia = @"play_media";
AnalyticsType const AnalyticsTypeActionDisplay = @"display";
AnalyticsType const AnalyticsTypeActionDisplayShow = @"display_show";
AnalyticsType const AnalyticsTypeActionCancel = @"cancel";
AnalyticsType const AnalyticsTypeActionNotificationAlert = @"notification_alert";
AnalyticsType const AnalyticsTypeActionDisplayLogin = @"display_login";
AnalyticsType const AnalyticsTypeActionCancelLogin = @"cancel_login";
AnalyticsType const AnalyticsTypeActionLogin = @"login";
AnalyticsType const AnalyticsTypeActionLogout = @"logout";

AnalyticsValue const AnalyticsTypeValueSharingContent = @"content";
AnalyticsValue const AnalyticsTypeValueSharingContentAtTime = @"content_at_time";
AnalyticsValue const AnalyticsTypeValueSharingCurrentClip = @"current_clip";
