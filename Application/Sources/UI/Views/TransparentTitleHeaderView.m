//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "TransparentTitleHeaderView.h"

#import "UIColor+PlaySRG.h"

#import <SRGAppearance/SRGAppearance.h>

@interface TransparentTitleHeaderView ()

@property (nonatomic, weak) IBOutlet UILabel *titleLabel;

@end

@implementation TransparentTitleHeaderView

#pragma mark Overrides

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.titleLabel.textColor = UIColor.play_lightGrayColor;
}

#pragma mark Getters and setters

- (void)setTitle:(NSString *)title
{
    _title = title;
    
    self.titleLabel.text = title;
    self.titleLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleTitle];
}

#pragma mark Accessibility

- (BOOL)isAccessibilityElement
{
    return YES;
}

- (NSString *)accessibilityLabel
{
    return self.titleLabel.text.lowercaseString;
}

- (UIAccessibilityTraits)accessibilityTraits
{
    return UIAccessibilityTraitHeader;
}

@end