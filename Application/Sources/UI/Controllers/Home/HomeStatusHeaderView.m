//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "HomeStatusHeaderView.h"

#import "NSBundle+PlaySRG.h"
#import "UIApplication+PlaySRG.h"
#import "UIColor+PlaySRG.h"

#import <SRGAppearance/SRGAppearance.h>

@interface HomeStatusHeaderView ()

@property (nonatomic, weak) IBOutlet UIView *backgroundView;
@property (nonatomic, weak) IBOutlet UILabel *messageLabel;

@end

@implementation HomeStatusHeaderView

#pragma mark Class methods

+ (CGFloat)heightForServiceMessage:(SRGServiceMessage *)serviceMessage withSize:(CGSize)size
{
    HomeStatusHeaderView *headerView = [NSBundle.mainBundle loadNibNamed:NSStringFromClass(self) owner:nil options:nil].firstObject;
    headerView.serviceMessage = serviceMessage;
    
    // Force autolayout with correct frame width so that the layout is accurate
    headerView.frame = CGRectMake(CGRectGetMinX(headerView.frame), CGRectGetMinY(headerView.frame), size.width, CGRectGetHeight(headerView.frame));
    [headerView setNeedsLayout];
    [headerView layoutIfNeeded];
    
    // Return the minimum size which satisfies the constraints. Put a strong requirement on width and properly let the height
    // adjust
    // For an explanation, see http://titus.io/2015/01/13/a-better-way-to-autosize-in-ios-8.html
    CGSize fittingSize = UILayoutFittingCompressedSize;
    fittingSize.width = size.width;
    return [headerView systemLayoutSizeFittingSize:fittingSize
                     withHorizontalFittingPriority:UILayoutPriorityRequired
                           verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height;
}

#pragma mark Overrides

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.messageLabel.textColor = UIColor.whiteColor;
    self.backgroundView.backgroundColor = UIColor.play_redColor;
    
    self.backgroundView.layer.cornerRadius = 2.f;
}

#pragma mark Getters and setters

- (void)setServiceMessage:(SRGServiceMessage *)serviceMessage
{
    _serviceMessage = serviceMessage;
    
    if (serviceMessage.text) {
        NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:serviceMessage.text
                                                                                           attributes:@{ NSFontAttributeName : [UIFont srg_regularFontWithTextStyle:SRGAppearanceFontTextStyleBody] }];
        if (serviceMessage.URL) {
            [attributedText appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" %@", NSLocalizedString(@"Learn more", @"Label inviting the user to learn more information about an issue")]
                                                                                   attributes:@{ NSFontAttributeName : [UIFont srg_boldFontWithTextStyle:SRGAppearanceFontTextStyleBody] }]];
        }
        self.messageLabel.attributedText = attributedText.copy;
    }
    else {
        self.messageLabel.attributedText = nil;
    }
}

#pragma mark Accessibility

- (BOOL)isAccessibilityElement
{
    return YES;
}

- (CGRect)accessibilityFrame
{
    return UIAccessibilityConvertFrameToScreenCoordinates(self.backgroundView.frame, self);
}

- (NSString *)accessibilityLabel
{
    return self.messageLabel.attributedText.string;
}

- (NSString *)accessibilityHint
{
    if (self.serviceMessage.URL) {
        return PlaySRGAccessibilityLocalizedString(@"Opens details.", @"Status header action hint");
    }
    else {
        return nil;
    }
}

#pragma mark Actions

- (IBAction)didTap:(id)sender
{
    NSURL *URL = self.serviceMessage.URL;
    if (URL) {
        [UIApplication.sharedApplication play_openURL:URL withCompletionHandler:nil];
    }
}

@end
