//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SettingsBaseViewController.h"

#import "SettingTableViewCell.h"
#import "UIColor+PlaySRG.h"
#import "UIViewController+PlaySRG.h"

#import "InAppSettingsKit/IASKSettingsReader.h"
#import <objc/runtime.h>
#import <SRGAppearance/SRGAppearance.h>

@implementation SettingsBaseViewController

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = UIColor.play_blackColor;
    self.tableView.separatorColor = UIColor.play_grayColor;
    
    self.neverShowPrivacySettings = YES;
    self.delegate = self;
    
    self.showDoneButton = NO;
    self.showCreditsFooter = NO;
}

#pragma mark Rotation

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return [super supportedInterfaceOrientations] & UIViewController.play_supportedInterfaceOrientations;
}

#pragma mark Status bar

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

#pragma mark ContentInsets protocol

- (NSArray<UIScrollView *> *)play_contentScrollViews
{
    return self.tableView ? @[self.tableView] : nil;
}

- (UIEdgeInsets)play_paddingContentInsets
{
    return UIEdgeInsetsZero;
}

#pragma mark IASKSettingsDelegate protocol

- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController *)sender
{}

- (UIView *)settingsViewController:(id<IASKViewController>)settingsViewController tableView:(UITableView *)tableView viewForHeaderForSection:(NSInteger)section
{
    // We must return a view for the header so that the height delegate method gets called
    return [[UITableViewHeaderFooterView alloc] initWithFrame:CGRectZero];
}

- (CGFloat)settingsViewController:(id<IASKViewController>)settingsViewController tableView:(UITableView *)tableView heightForHeaderForSection:(NSInteger)section
{
    BOOL hasTitle = [self tableView:tableView titleForHeaderInSection:section].length != 0;
    if (section == 0) {
        return hasTitle ? 75.f : 15.f;
    }
    else {
        return hasTitle ? 60.f : 0.1f /* Cannot use 0 = automatic dimension */;
    }
}

- (UIView *)settingsViewController:(id<IASKViewController>)settingsViewController tableView:(UITableView *)tableView viewForFooterForSection:(NSInteger)section
{
    // We must return a view for the footer so that the height delegate method gets called
    return [[UITableViewHeaderFooterView alloc] initWithFrame:CGRectZero];
}

- (CGFloat)settingsViewController:(id<IASKViewController>)settingsViewController tableView:(UITableView *)tableView heightForFooterForSection:(NSInteger)section
{
    BOOL hasFooter = [self tableView:tableView titleForFooterInSection:section].length != 0;
    return hasFooter ? UITableViewAutomaticDimension : 0.1f /* Cannot use 0 = automatic dimension */;
}

#pragma mark UITableViewDelegate protocol

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // For cells with a standard (in our case ugly) selection effect, replace with a custom cell subclass
    // providing a better effect.
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    if (cell.selectionStyle != UITableViewCellSelectionStyleNone) {
        object_setClass(cell, SettingTableViewCell.class);
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.backgroundColor = [UIColor colorWithWhite:1.f alpha:0.02f];
    cell.textLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleBody];
    cell.textLabel.textColor = UIColor.whiteColor;
    cell.detailTextLabel.font = [UIFont srg_regularFontWithTextStyle:SRGAppearanceFontTextStyleBody];
    cell.tintColor = UIColor.whiteColor;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UITableViewHeaderFooterView *)view forSection:(NSInteger)section
{
    view.textLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleTitle];
    view.textLabel.textColor = UIColor.play_lightGrayColor;
}

- (void)tableView:(UITableView *)tableView willDisplayFooterView:(UITableViewHeaderFooterView *)view forSection:(NSInteger)section
{
    view.textLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleSubtitle];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
    
    // Fix ugly behavior of InAppSettingsKit
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
