//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <SRGLetterbox/SRGLetterbox.h>

NS_ASSUME_NONNULL_BEGIN

@interface Playlist : NSObject <SRGLetterboxControllerPlaylistDataSource>

- (instancetype)initWithURN:(NSString *)URN;

@property (nonatomic, nullable, readonly) NSString *recommendationUid;
@property (nonatomic, nullable, readonly) NSArray<NSString *> *URNs;

@end

NS_ASSUME_NONNULL_END
