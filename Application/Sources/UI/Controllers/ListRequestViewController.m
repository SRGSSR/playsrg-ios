//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "ListRequestViewController.h"

#import "UIViewController+PlaySRG.h"

#import <libextobjc/libextobjc.h>

@interface ListRequestViewController ()

@property (nonatomic) SRGRequestQueue *requestQueue;

@property (nonatomic) NSUInteger numberOfLoadedPages;
@property (nonatomic) NSArray *items;
@property (nonatomic) SRGPage *nextPage;

@end

@implementation ListRequestViewController

#pragma mark Getters and setters

- (BOOL)isLoading
{
    return self.requestQueue.running;
}

- (BOOL)canLoadMoreItems
{
    return self.nextPage != nil;
}

#pragma mark View lifecycle

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    if ([self play_isMovingFromParentViewController]) {
        [self.requestQueue cancel];
    }
}

#pragma mark Data

- (void)refresh
{
    if (! [self shouldPerformRefreshRequest]) {
        [self didCancelRefreshRequest];
        return;
    }
    
    [self.requestQueue cancel];
    
    @weakify(self)
    self.requestQueue = [[SRGRequestQueue alloc] initWithStateChangeBlock:^(BOOL finished, NSError * _Nullable error) {
        @strongify(self)
        
        if (finished) {
            [self refreshDidFinishWithError:error];
        }
        else {
            [self refreshDidStart];
        }
    }];
    
    NSMutableArray *loadingItems = [NSMutableArray array];
    
    __block SRGPage *loadingNextPage = nil;
    __block NSUInteger remainingNextPageRequests = (self.numberOfLoadedPages > 0) ? self.numberOfLoadedPages - 1 : 0;
    __block NSUInteger numberOfLoadedPages = 0;
    
    typedef void (^LoadPageBlock)(SRGPage * _Nullable);
    __block __weak LoadPageBlock weakLoadPage = nil;
    
    LoadPageBlock loadPage = ^(SRGPage * _Nullable page) {
        LoadPageBlock strongLoadPage = weakLoadPage;
        
        [self loadPage:page withCompletionBlock:^(NSArray * _Nullable items, SRGPage * _Nullable nextPage, NSError * _Nullable error) {
            if (error) {
                return;
            }
            
            [loadingItems addObjectsFromArray:items];
            loadingNextPage = nextPage;
            
            ++numberOfLoadedPages;
            
            if (remainingNextPageRequests > 0 && nextPage) {
                --remainingNextPageRequests;
                strongLoadPage(nextPage);
            }
            else {
                NSArray *items = [loadingItems copy];
                [self updateWithItems:items previousItems:self.items completion:^{
                    self.items = items;
                }];
                self.nextPage = loadingNextPage;
                self.numberOfLoadedPages = numberOfLoadedPages;
            }
        }];
    };
    weakLoadPage = loadPage;
    
    loadPage(nil);
}

- (void)loadNextPage
{
    if (self.loading || ! self.nextPage) {
        return;
    }
    
    [self loadPage:self.nextPage withCompletionBlock:^(NSArray * _Nullable pageItems, SRGPage * _Nullable nextPage, NSError * _Nullable error) {
        if (error) {
            return;
        }
        
        NSArray *items = [self.items arrayByAddingObjectsFromArray:pageItems];
        [self updateWithItems:items previousItems:self.items completion:^{
            self.items = items;
            self.nextPage = nextPage;
            ++self.numberOfLoadedPages;
        }];
    }];
}

- (void)clear
{
    [self.requestQueue cancel];
    
    [self refreshDidStart];
    
    [self updateWithItems:nil previousItems:self.items completion:^{
        self.items = nil;
        self.nextPage = nil;
        self.numberOfLoadedPages = 0;
    }];
    
    [self refreshDidFinishWithError:nil];
}

- (void)loadPage:(SRGPage *)page withCompletionBlock:(void (^)(NSArray * _Nullable items, SRGPage * _Nullable nextPage, NSError * _Nullable error))completionBlock
{
    NSParameterAssert(completionBlock);
    
    [self prepareRefreshWithRequestQueue:self.requestQueue page:page completionHandler:^(NSArray * _Nullable items, SRGPage * _Nonnull page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error) {
        if (error) {
            [self.requestQueue reportError:error];
            return;
        }
        
        completionBlock(items, nextPage, error);
    }];
}

#pragma mark Stubs

- (BOOL)shouldPerformRefreshRequest
{
    return YES;
}

- (void)didCancelRefreshRequest
{}

- (SRGRequest *)requestForListWithCompletionHandler:(ListRequestPageCompletionHandler)completionHandler
{
    HLSMissingMethodImplementation();
    return [SRGRequest new];
}

- (void)refreshDidStart
{}

- (void)refreshDidFinishWithError:(NSError *)error
{}

- (void)updateWithItems:(NSArray *)items previousItems:(NSArray *)previousItems completion:(void (NS_NOESCAPE ^)(void))completion
{
    completion();
}

@end
