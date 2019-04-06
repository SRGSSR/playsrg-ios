//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "WatchLater.h"

#import "ApplicationConfiguration.h"
#import "Download.h"
#import "NSTimer+PlaySRG.h"

#import <libextobjc/libextobjc.h>
#import <SRGLetterbox/SRGLetterbox.h>
#import <SRGUserData/SRGUserData.h>

static NSMutableDictionary<NSString *, NSNumber *> *s_cachedProgresses;
static NSMutableDictionary<NSString *, NSString *> *s_tasks;
static NSTimer *s_trackerTimer;

#pragma mark Media metadata functions

BOOL WatchLaterContainsMediaMetadata(id<SRGMediaMetadata> mediaMetadata)
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == NO && %K == %@", @keypath(SRGPlaylistEntry.new, discarded), @keypath(SRGPlaylistEntry.new, uid), mediaMetadata.URN];
    return [SRGUserData.currentUserData.playlists entriesFromPlaylistWithUid:SRGWatchLaterPlaylistUid matchingPredicate:predicate sortedWithDescriptors:nil].count > 0;
}

void WatchLaterAddMediaMetadata(id<SRGMediaMetadata> mediaMetadata, void (^completion)(NSError * _Nullable error))
{
    [SRGUserData.currentUserData.playlists addEntryWithUid:mediaMetadata.URN toPlaylistWithUid:SRGWatchLaterPlaylistUid completionBlock:^(NSError * _Nullable error) {
         dispatch_async(dispatch_get_main_queue(), ^{
             completion(error);
         });
    }];
}

void WatchLaterRemoveMediaMetadata(id<SRGMediaMetadata> mediaMetadata, void (^completion)(NSError * _Nullable error))
{
    [SRGUserData.currentUserData.playlists removeEntriesWithUids:@[mediaMetadata.URN] fromPlaylistWithUid:SRGWatchLaterPlaylistUid completionBlock:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(error);
        });
    }];
}

void WatchLaterToggleMediaMetadata(id<SRGMediaMetadata> _Nonnull mediaMetadata, void (^completion)(BOOL added, NSError * _Nullable error))
{
    BOOL contains = WatchLaterContainsMediaMetadata(mediaMetadata);
    if (contains) {
        WatchLaterRemoveMediaMetadata(mediaMetadata, ^(NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, error);
            });
        });
    }
    else {
        WatchLaterAddMediaMetadata(mediaMetadata, ^(NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(YES, error);
            });
        });
    }
}
