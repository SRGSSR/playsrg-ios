//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SearchLoadingCollectionViewCell.h"

#import "NSBundle+PlaySRG.h"
#import "UIColor+PlaySRG.h"
#import "UIImageView+PlaySRG.h"

@interface SearchLoadingCollectionViewCell ()

@property (nonatomic, weak) IBOutlet UIImageView *imageView;

@end

@implementation SearchLoadingCollectionViewCell

#pragma mark Overrides

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.backgroundColor = UIColor.clearColor;
    [self.imageView play_setLoadingAnimation90WithTintColor:UIColor.play_lightGrayColor];
    [self.imageView startAnimating];
}

#pragma mark Accessibility

- (BOOL)isAccessibilityElement
{
    return NO;
}

@end
