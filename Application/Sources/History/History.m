//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "History.h"

#import "ApplicationConfiguration.h"
#import "Download.h"
#import "NSTimer+PlaySRG.h"

#import <GoogleCast/GoogleCast.h>
#import <SRGLetterbox/SRGLetterbox.h>
#import <SRGUserData/SRGUserData.h>

static NSMutableDictionary<NSString *, NSNumber *> *s_cachedProgresses;
static NSTimer *s_trackerTimer;

#pragma mark Helpers

float HistoryPlaybackProgress(NSTimeInterval playbackPosition, double durationInSeconds)
{
    NSTimeInterval durationWithToleranceInSeconds = fmax(durationInSeconds - ApplicationConfigurationEffectiveEndTolerance(durationInSeconds), 0.f);
    if (durationWithToleranceInSeconds == 0.f) {
        return 1.f;
    }
    else {
        return fmax(fmin(playbackPosition / durationWithToleranceInSeconds, 1.f), 0.f);
    }
}

SRGPosition *HistoryResumePlaybackPositionForMedia(SRGMedia *media)
{
    // Always start at the default location for livestreams and scheduled livestreams
    if (media.contentType == SRGContentTypeLivestream || media.contentType == SRGContentTypeScheduledLivestream) {
        return nil;
    }
    
    // Allow faster seek to an earlier position, but not to a later position (playback for a history entry should not resume with
    // content the user has not seen yet)
    SRGHistoryEntry *historyEntry = [SRGUserData.currentUserData.history historyEntryWithUid:media.URN];
    if (historyEntry) {
        return [SRGPosition positionBeforeTime:historyEntry.lastPlaybackTime];
    }
    else {
        return nil;
    }
}

static SRGMedia *HistoryChapterMedia(SRGLetterboxController *controller)
{
    SRGMediaComposition *mediaComposition = controller.mediaComposition;
    if (mediaComposition) {
        return [mediaComposition mediaForSubdivision:mediaComposition.mainChapter];
    }
    
    SRGMedia *media = controller.media;
    if (media && [Download downloadForMedia:media]) {
        return media;
    }
    
    return nil;
}

#pragma mark Player tracker

__attribute__((constructor)) static void HistoryPlayerTrackerInit(void)
{
    s_cachedProgresses = [NSMutableDictionary dictionary];
    s_trackerTimer = [NSTimer play_timerWithTimeInterval:1. repeats:YES block:^(NSTimer * _Nonnull timer) {
        NSString *deviceUid = UIDevice.currentDevice.name;
        
        GCKSession *session = [GCKCastContext sharedInstance].sessionManager.currentSession;
        if (session) {
            GCKRemoteMediaClient *remoteMediaClient = session.remoteMediaClient;
            GCKMediaStatus *mediaStatus = remoteMediaClient.mediaStatus;
            if (mediaStatus.playerState != GCKMediaPlayerStatePlaying) {
                return;
            }
            
            // Only for on-demand streams
            GCKMediaInformation *mediaInformation = mediaStatus.mediaInformation;
            if (mediaInformation.streamType != GCKMediaStreamTypeBuffered) {
                return;
            }
            
            NSString *URN = mediaInformation.contentID;
            if (! URN) {
                return;
            }
            
            // Use approximate value. The value in GCKMediaStatus is updated from time to time. The approximateStreamPosition
            // interpolates between known values to get a smoother progress
            NSTimeInterval streamPosition = remoteMediaClient.approximateStreamPosition;
            [SRGUserData.currentUserData.history saveHistoryEntryWithUid:URN lastPlaybackTime:CMTimeMakeWithSeconds(streamPosition, NSEC_PER_SEC) deviceUid:deviceUid completionBlock:nil];
        }
        else {
            SRGLetterboxController *letterboxController = SRGLetterboxService.sharedService.controller;
            if (letterboxController.playbackState != SRGMediaPlayerPlaybackStatePlaying) {
                return;
            }
            
            SRGMedia *chapterMedia = HistoryChapterMedia(letterboxController);
            if (! chapterMedia || chapterMedia.contentType == SRGContentTypeLivestream) {
                return;
            }
            
            CMTime currentTime = letterboxController.currentTime;
            CMTime chapterPlaybackTime = (chapterMedia.contentType != SRGContentTypeScheduledLivestream && CMTIME_IS_VALID(currentTime)) ? currentTime : kCMTimeZero;
            
            // Save the segment position.
            SRGSubdivision *subdivision = letterboxController.subdivision;
            if ([subdivision isKindOfClass:SRGSegment.class]) {
                SRGSegment *segment = (SRGSegment *)subdivision;
                CMTime segmentPlaybackTime = CMTimeMaximum(CMTimeSubtract(chapterPlaybackTime, CMTimeMakeWithSeconds(segment.markIn / 1000., NSEC_PER_SEC)), kCMTimeZero);
                [SRGUserData.currentUserData.history saveHistoryEntryWithUid:segment.URN lastPlaybackTime:segmentPlaybackTime deviceUid:deviceUid completionBlock:nil];
            }
            
            // Save the main full-length position (update after the segment so that full-length entries are always more recent than corresponding
            // segment entries)
            [SRGUserData.currentUserData.history saveHistoryEntryWithUid:chapterMedia.URN lastPlaybackTime:chapterPlaybackTime deviceUid:deviceUid completionBlock:nil];
        }
    }];
}

#pragma mark Media metadata functions

static BOOL HistoryIsProgressForMediaMetadataTracked(id<SRGMediaMetadata> mediaMetadata)
{
    return mediaMetadata && mediaMetadata.duration > 0. && mediaMetadata.contentType != SRGContentTypeLivestream && mediaMetadata.contentType != SRGContentTypeScheduledLivestream;
}

static float HistoryPlaybackProgressForMediaMetadataHistoryEntry(SRGHistoryEntry *historyEntry, id<SRGMediaMetadata> mediaMetadata)
{
    NSCParameterAssert(historyEntry);
    return HistoryPlaybackProgress(CMTimeGetSeconds(historyEntry.lastPlaybackTime), mediaMetadata.duration / 1000.);
}

float HistoryPlaybackProgressForMediaMetadata(id<SRGMediaMetadata> mediaMetadata)
{
    if (HistoryIsProgressForMediaMetadataTracked(mediaMetadata)) {
        SRGHistoryEntry *historyEntry = [SRGUserData.currentUserData.history historyEntryWithUid:mediaMetadata.URN];
        return historyEntry ? HistoryPlaybackProgressForMediaMetadataHistoryEntry(historyEntry, mediaMetadata) : 0.f;
    }
    else {
        return 0.f;
    }
}

NSString *HistoryPlaybackProgressForMediaMetadataAsync(id<SRGMediaMetadata> mediaMetadata, void (^update)(float progress))
{
    if (! HistoryIsProgressForMediaMetadataTracked(mediaMetadata)) {
        update(0.f);
        return nil;
    }
    
    NSString *handle = [SRGUserData.currentUserData.history historyEntryWithUid:mediaMetadata.URN completionBlock:^(SRGHistoryEntry * _Nullable historyEntry, NSError * _Nullable error) {
        if (error) {
            return;
        }
        
        float progress = historyEntry ? HistoryPlaybackProgressForMediaMetadataHistoryEntry(historyEntry, mediaMetadata) : 0.f;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            s_cachedProgresses[mediaMetadata.URN] = (progress > 0.f) ? @(progress) : nil;
            update(progress);
        });
    }];
    
    NSNumber *cachedProgress = s_cachedProgresses[mediaMetadata.URN];
    update(cachedProgress.floatValue);
    
    return handle;
}

void HistoryPlaybackProgressAsyncCancel(NSString *handle)
{
    if (handle) {
        [SRGUserData.currentUserData.history cancelTaskWithHandle:handle];
    }
}
