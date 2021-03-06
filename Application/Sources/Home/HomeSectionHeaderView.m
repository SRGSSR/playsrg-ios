//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "HomeSectionHeaderView.h"

#import "ApplicationConfiguration.h"
#import "HomeMediasViewController.h"
#import "HomeTopicViewController.h"
#import "Layout.h"
#import "ModuleViewController.h"
#import "NSBundle+PlaySRG.h"
#import "PageViewController.h"
#import "SRGModule+PlaySRG.h"
#import "UIView+PlaySRG.h"

@import SRGAppearance;

@interface HomeSectionHeaderView ()

@property (nonatomic, weak) IBOutlet UIView *moduleBackgroundView;
@property (nonatomic, weak) IBOutlet UILabel *titleLabel;
@property (nonatomic, weak) IBOutlet UIButton *navigationButton;

@property (nonatomic, weak) IBOutlet NSLayoutConstraint *leadingTitleLabelLayoutConstraint;

@end

@implementation HomeSectionHeaderView

#pragma mark Getters and setters

- (void)setHomeSectionInfo:(HomeSectionInfo *)homeSectionInfo
{
    _homeSectionInfo = homeSectionInfo;
    
    self.moduleBackgroundView.backgroundColor = homeSectionInfo.module.play_backgroundColor;
    
    self.titleLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleTitle];
    self.titleLabel.text = homeSectionInfo.title;
    
    self.navigationButton.hidden = ! [homeSectionInfo canOpenList] || ! self.titleLabel.text;
}

#pragma mark Overrides

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.titleLabel.textColor = UIColor.whiteColor;
    self.titleLabel.userInteractionEnabled = YES;
    
    self.leadingTitleLabelLayoutConstraint.constant = LayoutStandardMargin;
    
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openMediaList:)];
    [self.titleLabel addGestureRecognizer:tapGestureRecognizer];
    
    self.navigationButton.tintColor = UIColor.whiteColor;
}

#pragma mark Accessibility

- (BOOL)isAccessibilityElement
{
    return YES;
}

- (NSString *)accessibilityLabel
{
    return self.homeSectionInfo.title;
}

- (NSString *)accessibilityHint
{
    HomeSectionInfo *homeSectionInfo = self.homeSectionInfo;
    return [homeSectionInfo canOpenList] ? PlaySRGAccessibilityLocalizedString(@"Shows all contents.", @"Homepage header action hint") : nil;
}

- (UIAccessibilityTraits)accessibilityTraits
{
    return UIAccessibilityTraitHeader;
}

#pragma mark Actions

- (IBAction)openMediaList:(id)sender
{
    HomeSectionInfo *homeSectionInfo = self.homeSectionInfo;
    if (! [homeSectionInfo canOpenList]) {
        return;
    }
    
    UIViewController *viewController = nil;
    if (self.homeSectionInfo.module) {
        viewController = [[ModuleViewController alloc] initWithModule:self.homeSectionInfo.module];
    }
    else if ([self.homeSectionInfo.topic isKindOfClass:SRGTopic.class]) {
        viewController = [[HomeTopicViewController alloc] initWithTopic:(SRGTopic *)self.homeSectionInfo.topic];
    }
    else {
        viewController = [[HomeMediasViewController alloc] initWithHomeSectionInfo:homeSectionInfo];
    }
    [self.play_nearestViewController.navigationController pushViewController:viewController animated:YES];
}

@end
