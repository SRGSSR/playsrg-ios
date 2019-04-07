//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "WatchLater.h"

#import "Favorite+Private.h"

#import <libextobjc/libextobjc.h>
#import <SRGUserData/SRGUserData.h>

@interface SRGPlaylists (Private)

- (void)saveEntryDictionaries:(NSArray<NSDictionary *> *)playlistEntryDictionaries toPlaylistUid:(NSString *)playlistUid withCompletionBlock:(void (^)(NSError * _Nullable error))completionBlock;

@end

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

void WatchLaterMigrate()
{
    NSArray<Favorite *> *favorites = [Favorite mediaFavorites];
    if (favorites.count > 0) {
        NSMutableArray<NSDictionary *> *mediaDictionaries = [NSMutableArray array];
        for (Favorite *favorite in favorites) {
            [mediaDictionaries addObject:favorite.watchLaterDictionary];
        }
        [SRGUserData.currentUserData.playlists saveEntryDictionaries:mediaDictionaries.copy toPlaylistUid:SRGWatchLaterPlaylistUid withCompletionBlock:^(NSError * _Nullable error) {
            if (! error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [Favorite finishMigrationForFavorites:favorites];
                });
            }
        }];
    }
}
