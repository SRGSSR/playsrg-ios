//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <CoconutKit/CoconutKit.h>
#import <SRGDataProvider/SRGDataProvider.h>

NS_ASSUME_NONNULL_BEGIN

@interface HomeStatusHeaderView : HLSNibView

+ (CGFloat)heightForServiceMessage:(SRGServiceMessage *)serviceMessage withSize:(CGSize)size;

@property (nonatomic, nullable) SRGServiceMessage *serviceMessage;

@end

NS_ASSUME_NONNULL_END
