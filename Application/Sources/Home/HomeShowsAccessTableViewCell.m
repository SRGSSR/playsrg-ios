//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "HomeShowsAccessTableViewCell.h"

#import "ApplicationConfiguration.h"
#import "CalendarViewController.h"
#import "NSBundle+PlaySRG.h"
#import "ShowsViewController.h"
#import "UIColor+PlaySRG.h"
#import "UILabel+PlaySRG.h"
#import "UIViewController+PlaySRG.h"

#import <SRGAppearance/SRGAppearance.h>

@interface HomeShowsAccessTableViewCell ()

@property (nonatomic, readonly, getter=isDataAvailable) BOOL dataAvailable;

@property (nonatomic, weak) IBOutlet UIView *mainView;
@property (nonatomic, weak) IBOutlet UIView *placeholderView;

@property (nonatomic, weak) IBOutlet UIView *showsAtoZButtonPlaceholderView;
@property (nonatomic, weak) IBOutlet UIView *showsByDateButtonPlaceholderView;

@property (nonatomic, weak) IBOutlet UIButton *showsAtoZButton;
@property (nonatomic, weak) IBOutlet UIButton *showsByDateButton;

@end

@implementation HomeShowsAccessTableViewCell

#pragma mark Overrides

+ (CGFloat)heightForHomeSectionInfo:(HomeSectionInfo *)homeSectionInfo bounds:(CGRect)bounds featured:(BOOL)featured
{
    return 50.f;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.mainView.hidden = YES;
    self.placeholderView.hidden = NO;
    
    self.showsAtoZButtonPlaceholderView.backgroundColor = UIColor.play_lightGrayButtonBackgroundColor;
    self.showsAtoZButtonPlaceholderView.layer.cornerRadius = 4.f;
    self.showsAtoZButtonPlaceholderView.layer.masksToBounds = YES;
    
    self.showsByDateButtonPlaceholderView.backgroundColor = UIColor.play_lightGrayButtonBackgroundColor;
    self.showsByDateButtonPlaceholderView.layer.cornerRadius = 4.f;
    self.showsByDateButtonPlaceholderView.layer.masksToBounds = YES;

    self.backgroundColor = UIColor.play_blackColor;
    self.selectedBackgroundView.backgroundColor = UIColor.clearColor;
    
    self.showsAtoZButton.backgroundColor = UIColor.play_lightGrayButtonBackgroundColor;
    self.showsAtoZButton.layer.cornerRadius = 4.f;
    self.showsAtoZButton.layer.masksToBounds = YES;
    [self.showsAtoZButton setTitle:NSLocalizedString(@"A to Z", @"Short title displayed in home page shows section.") forState:UIControlStateNormal];
    self.showsAtoZButton.accessibilityLabel = PlaySRGAccessibilityLocalizedString(@"Programmes A-Z", @"Title displayed in home page shows section.");
    
    self.showsByDateButton.backgroundColor = UIColor.play_lightGrayButtonBackgroundColor;
    self.showsByDateButton.layer.cornerRadius = 4.f;
    self.showsByDateButton.layer.masksToBounds = YES;
    [self.showsByDateButton setTitle:NSLocalizedString(@"By date", @"Short title displayed in home page shows section.") forState:UIControlStateNormal];
    self.showsByDateButton.accessibilityLabel = PlaySRGAccessibilityLocalizedString(@"Programmes by date", @"Title displayed in home page shows section.");
    
    [self reloadData];
}

#pragma mark Accessibility

- (BOOL)isAccessibilityElement
{
    return NO;
}

- (NSArray *)accessibilityElements
{
    return self.dataAvailable ? @[self.showsAtoZButton, self.showsByDateButton] : nil;
}

#pragma mark Getters and setters

- (void)setHomeSectionInfo:(HomeSectionInfo *)homeSectionInfo featured:(BOOL)featured
{
    [super setHomeSectionInfo:homeSectionInfo featured:featured];
    
    [self reloadData];
}

#pragma mark UI

- (BOOL)isDataAvailable
{
    if (self.homeSectionInfo.homeSection == HomeSectionRadioShowsAccess) {
        return ([[ApplicationConfiguration sharedApplicationConfiguration] radioChannelForUid:self.homeSectionInfo.identifier] != nil);
    }
    else {
        return YES;
    }
}

- (void)reloadData
{
    if (! self.dataAvailable) {
        self.mainView.hidden = YES;
        self.placeholderView.hidden = NO;
        return;
    }
    
    self.mainView.hidden = NO;
    self.placeholderView.hidden = YES;
    
    self.showsAtoZButton.titleLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleBody];
    self.showsByDateButton.titleLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleBody];
}

#pragma mark Actions

- (IBAction)openShowsAZ:(id)sender
{
    RadioChannel *radioChannel = [[ApplicationConfiguration sharedApplicationConfiguration] radioChannelForUid:self.homeSectionInfo.identifier];
    UIViewController *viewController = [[ShowsViewController alloc] initWithRadioChannel:radioChannel alphabeticalIndex:nil];
    [self.nearestViewController.navigationController pushViewController:viewController animated:YES];
}

- (IBAction)openShowsByDate:(id)sender
{
    RadioChannel *radioChannel = [[ApplicationConfiguration sharedApplicationConfiguration] radioChannelForUid:self.homeSectionInfo.identifier];
    UIViewController *viewController = [[CalendarViewController alloc] initWithRadioChannel:radioChannel date:nil];
    [self.nearestViewController.navigationController pushViewController:viewController animated:YES];
}

@end
