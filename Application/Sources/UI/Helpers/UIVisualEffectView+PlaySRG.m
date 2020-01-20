//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UIVisualEffectView+PlaySRG.h"

@implementation UIVisualEffectView (PlaySRG)

#pragma mark Class methods

+ (UIVisualEffectView *)play_blurView
{
    UIBlurEffectStyle blurEffectStyle;
    if (@available(iOS 13, *)) {
        blurEffectStyle = UIBlurEffectStyleSystemMaterialDark;
    }
    else {
        blurEffectStyle = UIBlurEffectStyleDark;
    }
    UIVisualEffect *blurEffect = [UIBlurEffect effectWithStyle:blurEffectStyle];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    if (@available(iOS 13, *)) {
        blurView.backgroundColor = nil;
    }
    else {
        blurView.backgroundColor = [UIColor colorWithWhite:0.5f alpha:0.5f];
    }
    return blurView;
}

@end
