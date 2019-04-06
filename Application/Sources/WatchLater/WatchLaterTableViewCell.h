//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "Previewing.h"

#import <MGSwipeTableCell/MGSwipeTableCell.h>
#import <SRGDataProvider/SRGDataProvider.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class WatchLaterTableViewCell;

@protocol WatchLaterTableViewCellDelegate <NSObject>

- (void)watchLaterTableViewCell:(WatchLaterTableViewCell *)watchLaterTableViewCell deletePlaylistEntryForMedia:(SRGMedia *)media;

@end

@interface WatchLaterTableViewCell : MGSwipeTableCell <Previewing>

@property (nonatomic, nullable) SRGMedia *media;
@property (nonatomic, weak) id<WatchLaterTableViewCellDelegate> cellDelegate;

@end

NS_ASSUME_NONNULL_END
