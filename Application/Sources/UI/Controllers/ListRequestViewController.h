//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "DataViewController.h"

#import <SRGDataProvider/SRGDataProvider.h>

NS_ASSUME_NONNULL_BEGIN

// Types
typedef void (^ListRequestPageCompletionHandler)(NSArray * _Nullable items, SRGPage *page, SRGPage * _Nullable nextPage, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error);
typedef void (^ListRequestCompletionBlock)(NSArray * _Nullable items, NSHTTPURLResponse * _Nullable HTTPResponse, NSError * _Nullable error);

/**
 *  Abstract base view controller class for custom view controllers retrieving paginated lists of objects. Subclasses must 
 *  implement methods from the Subclassing category to specify the data retrieval process
 *
 *  In addition to behaviors inherited from `DataViewController`, this class provides the following features:
 *   - Clean mechanism for data retrieval
 *   - Support for several pages of content
 *
 *  Pages are cached as retrieved, `-refresh` only refreshes the current page set. To start again with the first page
 *  (therefore potentially loading new results), `-clear` results first.
 */
@interface ListRequestViewController : DataViewController

/**
 *  Refresh the current page set (always comprises at least the first page). Call `-loadNextPage` to load subsequent pages
 */
- (void)refresh;

/**
 *  Request the data for the next page. If a request is already running, this method does nothing
 */
- (void)loadNextPage;

/**
 *  Clear the current page set, starting again with the first page
 */
- (void)clear;

/**
 *  Return YES when data is being loaded
 */
@property (nonatomic, readonly, getter=isLoading) BOOL loading;

/**
 *  Return YES iff -loadNextPage can be called to gather more data
 */
@property (nonatomic, readonly) BOOL canLoadMoreItems;

/**
 *  The list of items which have been retrieved for the current pages
 */
@property (nonatomic, readonly, nullable) NSArray *items;

@end

/**
 *  Subclassing hooks
 */
@interface ListRequestViewController (Subclassing)

/**
 *  This method is called when a refresh request is about to be made. The default implementation returns YES. If YES is 
 *  returned and any request (refresh or loading) is currently being made, it will be cancelled first
 *
 *  @return YES if the refresh request must be made, no otherwise
 */
- (BOOL)shouldPerformRefreshRequest;

/**
 *  Called when the refresh request has been cancelled.
 */
- (void)didCancelRefreshRequest NS_REQUIRES_SUPER;

/**
 *  When `-refresh` or `-loadNextPage` are called, this method is called to retrieve the request to be called for a specific
 *  page. Subclasses can register as much requests as needed with the provided queue and, once all data for the page
 *  has been retrieved, MUST call the received completion handler to return result information
 *
 *  @param completionHandler A completion handler which MUST be called when the page has been loaded. Failure to call 
 *                           this block results in undefined behavior
 *
 *  @discussion Any error returned to the completion handler is automatically reported to the request queue, you do not have
 *              to do it yourself
 */
- (void)prepareRefreshWithRequestQueue:(SRGRequestQueue *)requestQueue page:(nullable SRGPage *)page completionHandler:(ListRequestPageCompletionHandler)completionHandler;

/**
 *  Called when a refresh has just started / ended
 *
 *  @discussion Also called when the list is cleared
 */
- (void)refreshDidStart;
- (void)refreshDidFinishWithError:(nullable NSError *)error;

- (void)updateWithItems:(nullable NSArray *)items previousItems:(nullable NSArray *)previousItems completion:(void (NS_NOESCAPE ^)(void))completion;

@end

NS_ASSUME_NONNULL_END
