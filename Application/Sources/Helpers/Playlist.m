//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "Playlist.h"

#import "ApplicationSettings.h"
#import "History.h"
#import "Recommendation.h"

#import <FXReachability/FXReachability.h>
#import <libextobjc/libextobjc.h>
#import <SRGNetwork/SRGNetwork.h>

@interface Playlist ()

@property (nonatomic, copy) NSString *URN;

@property (nonatomic) NSString *recommendationUid;

@property (nonatomic) NSArray<SRGMedia *> *medias;
@property (nonatomic) NSUInteger index;

@property (nonatomic) SRGRequestQueue *requestQueue;

@end

@implementation Playlist

#pragma mark Object lifecycle

- (instancetype)initWithURN:(NSString *)URN
{
    if (self = [super init]) {
        self.URN = URN;
        [self load];
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(reachabilityDidChange:)
                                                   name:FXReachabilityStatusDidChangeNotification
                                                 object:nil];
    }
    return self;
}

#pragma mark Helpers

- (void)load
{
    if (self.medias) {
        return;
    }
    
    self.requestQueue = [[SRGRequestQueue alloc] init];
    
    NSString *resourcePath = [NSString stringWithFormat:@"api/v2/playlist/recommendation/continuousPlayback/%@", self.URN];
    NSURL *middlewareURL = ApplicationConfiguration.sharedApplicationConfiguration.middlewareURL;
    NSURL *URL = [NSURL URLWithString:resourcePath relativeToURL:middlewareURL];
    
    NSURLComponents *URLComponents = [NSURLComponents componentsWithString:URL.absoluteString];
    URLComponents.queryItems = @[ [NSURLQueryItem queryItemWithName:@"standalone" value:@"false"] ];
    
    SRGRequest *recommendationRequest = [[SRGRequest objectRequestWithURLRequest:[NSURLRequest requestWithURL:URLComponents.URL] session:NSURLSession.sharedSession parser:^id _Nullable(NSData * _Nonnull data, NSError * _Nullable __autoreleasing * _Nullable pError) {
        NSDictionary *JSONDictionary = SRGNetworkJSONDictionaryParser(data, pError);
        if (! JSONDictionary) {
            return nil;
        }
        
        return [MTLJSONAdapter modelOfClass:Recommendation.class fromJSONDictionary:JSONDictionary error:pError];
    } completionBlock:^(Recommendation * _Nullable recommendation, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error || ! recommendation) {
            return;
        }
        
        SRGBaseRequest *mediasRequest = [[SRGDataProvider.currentDataProvider mediasWithURNs:recommendation.URNs completionBlock:^(NSArray<SRGMedia *> * _Nullable medias, SRGPage * _Nonnull page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
            if (error) {
                return;
            }
            
            self.recommendationUid = recommendation.recommendationUid;
            
            NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(SRGMedia * _Nullable media, NSDictionary<NSString *,id> * _Nullable bindings) {
                return [media blockingReasonAtDate:NSDate.date] == SRGBlockingReasonNone && HistoryPlaybackProgressForMediaMetadata(media) != 1.f;
            }];
            self.medias = [medias filteredArrayUsingPredicate:predicate];
        }] requestWithPageSize:50];
        [self.requestQueue addRequest:mediasRequest resume:YES];
    }] requestWithOptions:SRGRequestOptionBackgroundCompletionEnabled];
    [self.requestQueue addRequest:recommendationRequest resume:YES];
}

#pragma mark Getters

- (NSArray<NSString *> *)URNs
{
    return [self.medias valueForKeyPath:@keypath(SRGMedia.new, URN)] ?: @[ self.URN ];
}

#pragma SRGLetterboxControllerPlaylistDataSource protocol

- (SRGMedia *)previousMediaForController:(SRGLetterboxController *)controller
{
    if (self.medias.count == 0) {
        return nil;
    }
    else {
        return self.index > 0 ? self.medias[self.index - 1] : nil;
    }
}

- (SRGMedia *)nextMediaForController:(SRGLetterboxController *)controller
{
    if (self.medias.count == 0) {
        return nil;
    }
    else {
        return self.index < self.medias.count - 1 ? self.medias[self.index + 1] : nil;
    }
}

- (NSTimeInterval)continuousPlaybackTransitionDurationForController:(SRGLetterboxController *)controller
{
    return ApplicationSettingContinuousPlaybackTransitionDuration();
}

- (void)controller:(SRGLetterboxController *)controller didTransitionToMedia:(SRGMedia *)media automatically:(BOOL)automatically
{
    self.index = [self.medias indexOfObject:media];
}

- (SRGPosition *)controller:(SRGLetterboxController *)controller startPositionForMedia:(SRGMedia *)media
{
    return HistoryResumePlaybackPositionForMedia(media);
}

- (SRGLetterboxPlaybackSettings *)controller:(SRGLetterboxController *)controller preferredSettingsForMedia:(SRGMedia *)media
{
    SRGLetterboxPlaybackSettings *playbackSettings = ApplicationSettingPlaybackSettings();
    playbackSettings.sourceUid = self.recommendationUid;
    return playbackSettings;
}

#pragma mark Notifications

- (void)reachabilityDidChange:(NSNotification *)notification
{
    if ([FXReachability sharedInstance].reachable) {
        [self load];
    }
}

@end
