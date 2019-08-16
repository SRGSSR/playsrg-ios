//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "Previewing.h"

#import <SRGDataProvider/SRGDataProvider.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MediaCollectionViewCell : UICollectionViewCell <Previewing>

// A default date formatting is applied, without displaying media type.
@property (nonatomic) SRGMedia *media;

// An optional date formatter can be provided, and displaying media type icon.
- (void)setMedia:(nullable SRGMedia *)media withDateFormatter:(nullable NSDateFormatter *)dateFormatter displayingMediaType:(BOOL)displayingMediaType;

@end

NS_ASSUME_NONNULL_END
