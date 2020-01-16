//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "ApplicationConfiguration.h"

#import <Foundation/Foundation.h>
#import <SRGDataProvider/SRGDataProvider.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^SRGPaginatedItemListCompletionBlock)(NSArray * _Nullable items, SRGPage *page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error);
typedef void (^SRGItemListCompletionBlock)(NSArray * _Nullable items, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error);

@interface HomeSectionInfo : NSObject

- (instancetype)initWithHomeSection:(HomeSection)homeSection topicSection:(TopicSection)topicSection object:(nullable id)object NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithHomeSection:(HomeSection)homeSection object:(nullable id)object;
- (instancetype)initWithHomeSection:(HomeSection)homeSection;

@property (nonatomic, readonly) HomeSection homeSection;
@property (nonatomic, readonly) Class cellClass;
@property (nonatomic, readonly) BOOL canOpenList;

@property (nonatomic, readonly, nullable) id object;

@property (nonatomic, readonly, copy, nullable) NSString *identifier;
@property (nonatomic, readonly, nullable) SRGModule *module;
@property (nonatomic, readonly, nullable) SRGBaseTopic *topic;
@property (nonatomic, readonly) TopicSection topicSection;

@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic) CGPoint contentOffset;

@property (nonatomic, readonly, nullable) NSArray *items;

- (void)refreshWithRequestQueue:(SRGRequestQueue *)requestQueue completionBlock:(nullable void (^)(NSError * _Nullable error))completionBlock;

- (nullable SRGBaseRequest *)requestWithPage:(nullable SRGPage *)page completionBlock:(SRGPaginatedItemListCompletionBlock)paginatedItemListCompletionBlock;

@end

NS_ASSUME_NONNULL_END
