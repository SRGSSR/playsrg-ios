//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "HomeSectionInfo.h"

#import "ApplicationConfiguration.h"
#import "ApplicationSettings.h"
#import "Favorites.h"
#import "HomeMediaListTableViewCell.h"
#import "HomeRadioLiveTableViewCell.h"
#import "HomeShowListTableViewCell.h"
#import "HomeShowsAccessTableViewCell.h"
#import "HomeShowVerticalListTableViewCell.h"

#import <libextobjc/libextobjc.h>
#import <SRGDataProvider/SRGDataProvider.h>

@interface HomeSectionInfo ()

@property (nonatomic) HomeSection homeSection;
@property (nonatomic) id object;
@property (nonatomic) TopicSection topicSection;

@property (nonatomic) NSArray *items;

@end

@implementation HomeSectionInfo

#pragma Object lifecycle

- (instancetype)initWithHomeSection:(HomeSection)homeSection topicSection:(TopicSection)topicSection object:(id)object
{
    if (self = [super init]) {
        self.homeSection = homeSection;
        self.topicSection = topicSection;
        self.object = object;
    }
    return self;
}

- (instancetype)initWithHomeSection:(HomeSection)homeSection object:(id)object
{
    return [self initWithHomeSection:homeSection topicSection:TopicSectionUnknown object:object];
}

- (instancetype)initWithHomeSection:(HomeSection)homeSection
{
    return [self initWithHomeSection:homeSection topicSection:TopicSectionUnknown object:nil];
}

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return [self initWithHomeSection:HomeSectionUnknown object:nil];
}

#pragma mark Getters and setters

- (Class)cellClass
{
    if (self.homeSection == HomeSectionRadioAllShows) {
        return HomeShowVerticalListTableViewCell.class;
    }
    else if (self.homeSection == HomeSectionTVShowsAccess || self.homeSection == HomeSectionRadioShowsAccess) {
        return HomeShowsAccessTableViewCell.class;
    }
    else if (self.homeSection == HomeSectionTVFavoriteShows || self.homeSection == HomeSectionRadioFavoriteShows) {
        return HomeShowListTableViewCell.class;
    }
    else {
        return HomeMediaListTableViewCell.class;
    }
}

- (BOOL)canOpenList
{
    return self.homeSection != HomeSectionTVLive && self.homeSection != HomeSectionRadioLive
        && self.homeSection != HomeSectionRadioAllShows
        && self.homeSection != HomeSectionTVShowsAccess && self.homeSection != HomeSectionRadioShowsAccess
        && self.homeSection != HomeSectionTVFavoriteShows && self.homeSection != HomeSectionRadioFavoriteShows
        && ! [self isPlaceholder];
}

- (BOOL)isPlaceholder
{
    return (self.homeSection == HomeSectionTVTopics || self.homeSection == HomeSectionTVEvents) && ! self.object;
}

- (NSString *)identifier
{
    return [self.object isKindOfClass:NSString.class] ? self.object : nil;
}

- (SRGModule *)module
{
    return [self.object isKindOfClass:SRGModule.class] ? self.object : nil;
}

- (SRGBaseTopic *)topic
{
    return [self.object isKindOfClass:SRGBaseTopic.class] ? self.object : nil;
}

- (SRGBaseRequest *)requestWithPage:(SRGPage *)page completionBlock:(SRGPaginatedItemListCompletionBlock)paginatedItemListCompletionBlock
{
    ApplicationConfiguration *applicationConfiguration = ApplicationConfiguration.sharedApplicationConfiguration;
    
    NSUInteger pageSize = applicationConfiguration.pageSize;
    SRGVendor vendor = applicationConfiguration.vendor;
    
    switch (self.homeSection) {
        case HomeSectionTVTrending: {
            return [SRGDataProvider.currentDataProvider tvTrendingMediasForVendor:vendor withLimit:@(pageSize) editorialLimit:applicationConfiguration.tvTrendingEditorialLimit episodesOnly:applicationConfiguration.tvTrendingEpisodesOnly completionBlock:^(NSArray<SRGMedia *> * _Nullable medias, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
                paginatedItemListCompletionBlock(medias, [SRGPage new] /* The request does not support pagination, but we need to return a page */, nil, HTTPResponse, error);
            }];
            break;
        }
            
        case HomeSectionTVFavoriteShows: {
            return [[SRGDataProvider.currentDataProvider showsWithURNs:FavoritesShowURNs().allObjects completionBlock:^(NSArray<SRGShow *> * _Nullable shows, SRGPage * _Nonnull page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(SRGShow.new, transmission), @(SRGTransmissionTV)];
                NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGShow.new, title) ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
                paginatedItemListCompletionBlock([[shows filteredArrayUsingPredicate:predicate] sortedArrayUsingDescriptors:@[sortDescriptor]], page, nextPage, HTTPResponse, error);
            }] requestWithPageSize:50];
            break;
        }
            
        case HomeSectionTVLive: {
            return [SRGDataProvider.currentDataProvider tvLivestreamsForVendor:vendor withCompletionBlock:^(NSArray<SRGMedia *> * _Nullable medias, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
                paginatedItemListCompletionBlock(medias, [SRGPage new] /* The request does not support pagination, but we need to return a page */, nil, HTTPResponse, error);
            }];
            break;
        }
            
        case HomeSectionTVEvents: {
            SRGModule *module = self.module;
            if (module) {
                return [[[SRGDataProvider.currentDataProvider latestMediasForModuleWithURN:module.URN completionBlock:paginatedItemListCompletionBlock] requestWithPageSize:pageSize] requestWithPage:page];
            }
            break;
        }
            
        case HomeSectionTVTopics: {
            SRGBaseTopic *topic = self.topic;
            if (topic) {
                if (self.topicSection == TopicSectionMostPopular) {
                    return [[[SRGDataProvider.currentDataProvider mostPopularMediasForTopicWithURN:topic.URN completionBlock:paginatedItemListCompletionBlock] requestWithPageSize:pageSize] requestWithPage:page];
                }
                else {
                    return [[[SRGDataProvider.currentDataProvider latestMediasForTopicWithURN:topic.URN completionBlock:paginatedItemListCompletionBlock] requestWithPageSize:pageSize] requestWithPage:page];
                }
            }
            break;
        }
            
        case HomeSectionTVLatest: {
            return [[[SRGDataProvider.currentDataProvider tvLatestMediasForVendor:vendor withCompletionBlock:paginatedItemListCompletionBlock] requestWithPageSize:pageSize] requestWithPage:page];
            break;
        }
            
        case HomeSectionTVMostPopular: {
            return [[[SRGDataProvider.currentDataProvider tvMostPopularMediasForVendor:vendor withCompletionBlock:paginatedItemListCompletionBlock] requestWithPageSize:pageSize] requestWithPage:page];
            break;
        }
            
        case HomeSectionTVSoonExpiring: {
            return [[[SRGDataProvider.currentDataProvider tvSoonExpiringMediasForVendor:vendor withCompletionBlock:paginatedItemListCompletionBlock] requestWithPageSize:pageSize] requestWithPage:page];
            break;
        }
            
        case HomeSectionTVLiveCenter: {
            return [[[SRGDataProvider.currentDataProvider liveCenterVideosForVendor:vendor withCompletionBlock:paginatedItemListCompletionBlock] requestWithPageSize:pageSize] requestWithPage:page];
            break;
        }
            
        case HomeSectionTVScheduledLivestreams: {
            return [[[SRGDataProvider.currentDataProvider tvScheduledLivestreamsForVendor:vendor withCompletionBlock:paginatedItemListCompletionBlock] requestWithPageSize:pageSize] requestWithPage:page];
            break;
        }
            
        case HomeSectionRadioLive: {
            NSString *identifier = self.identifier;
            if (identifier) {
                return [SRGDataProvider.currentDataProvider radioLivestreamsForVendor:vendor channelUid:identifier withCompletionBlock:^(NSArray<SRGMedia *> * _Nullable medias, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
                    paginatedItemListCompletionBlock(medias, [SRGPage new] /* The request does not support pagination, but we need to return a page */, nil, HTTPResponse, error);
                }];
            }
            else {
                return [SRGDataProvider.currentDataProvider radioLivestreamsForVendor:vendor contentProviders:SRGContentProvidersDefault withCompletionBlock:^(NSArray<SRGMedia *> * _Nullable medias, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
                    paginatedItemListCompletionBlock(medias, [SRGPage new] /* The request does not support pagination, but we need to return a page */, nil, HTTPResponse, error);
                }];
            }
            break;
        }
            
        case HomeSectionRadioFavoriteShows: {
            return [[SRGDataProvider.currentDataProvider showsWithURNs:FavoritesShowURNs().allObjects completionBlock:^(NSArray<SRGShow *> * _Nullable shows, SRGPage * _Nonnull page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@ AND %K == %@", @keypath(SRGShow.new, transmission), @(SRGTransmissionRadio), @keypath(SRGShow.new, primaryChannelUid), self.identifier];
                NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@keypath(SRGShow.new, title) ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
                paginatedItemListCompletionBlock([[shows filteredArrayUsingPredicate:predicate] sortedArrayUsingDescriptors:@[sortDescriptor]], page, nextPage, HTTPResponse, error);
            }] requestWithPageSize:50];
            break;
        }
            
        case HomeSectionRadioLatestEpisodes: {
            NSString *identifier = self.identifier;
            if (identifier) {
                return [[[SRGDataProvider.currentDataProvider radioLatestEpisodesForVendor:vendor channelUid:identifier withCompletionBlock:paginatedItemListCompletionBlock] requestWithPageSize:pageSize] requestWithPage:page];
            }
            break;
        }
            
        case HomeSectionRadioMostPopular: {
            NSString *identifier = self.identifier;
            if (identifier) {
                return [[[SRGDataProvider.currentDataProvider radioMostPopularMediasForVendor:vendor channelUid:identifier withCompletionBlock:paginatedItemListCompletionBlock] requestWithPageSize:pageSize] requestWithPage:page];
            }
            break;
        }
            
        case HomeSectionRadioLatest: {
            NSString *identifier = self.identifier;
            if (identifier) {
                return [[[SRGDataProvider.currentDataProvider radioLatestMediasForVendor:vendor channelUid:identifier withCompletionBlock:paginatedItemListCompletionBlock] requestWithPageSize:pageSize] requestWithPage:page];
            }
            break;
        }
            
        case HomeSectionRadioLatestVideos: {
            NSString *identifier = self.identifier;
            if (identifier) {
                return [[[SRGDataProvider.currentDataProvider radioLatestVideosForVendor:vendor channelUid:identifier withCompletionBlock:paginatedItemListCompletionBlock] requestWithPageSize:pageSize] requestWithPage:page];
            }
            break;
        }
            
        case HomeSectionRadioAllShows: {
            NSString *identifier = self.identifier;
            if (identifier) {
                return [[[SRGDataProvider.currentDataProvider radioShowsForVendor:vendor channelUid:identifier withCompletionBlock:paginatedItemListCompletionBlock] requestWithPageSize:SRGDataProviderUnlimitedPageSize] requestWithPage:page];
            }
            break;
        }
            
        default: {
            break;
        }
    }
    return nil;
}

#pragma mark Data

- (void)refreshWithRequestQueue:(SRGRequestQueue *)requestQueue completionBlock:(void (^)(NSError * _Nullable error))completionBlock
{
    SRGBaseRequest *request = [self requestWithPage:nil completionBlock:^(NSArray * _Nullable items, SRGPage * _Nonnull page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        if (error) {
            [requestQueue reportError:error];
            completionBlock ? completionBlock(error) : nil;
            return;
        }
        
        self.items = items;
        completionBlock ? completionBlock(nil) : nil;
    }];
    
    if (request) {
        [requestQueue addRequest:request resume:YES];
    }
}

#pragma mark Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; homeSection = %@; object = %@; title = %@; items = %@>",
            self.class,
            self,
            @(self.homeSection),
            self.object,
            self.title,
            self.items];
}

@end
