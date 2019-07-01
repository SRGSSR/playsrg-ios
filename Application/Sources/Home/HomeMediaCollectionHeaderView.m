//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "HomeMediaCollectionHeaderView.h"

#import "HomeTopicViewController.h"
#import "ModuleViewController.h"
#import "NSBundle+PlaySRG.h"
#import "SRGBaseTopic+PlaySRG.h"
#import "UIColor+PlaySRG.h"
#import "UIImageView+PlaySRG.h"

#import <CoconutKit/CoconutKit.h>
#import <SRGAppearance/SRGAppearance.h>

@interface HomeMediaCollectionHeaderView ()

@property (nonatomic) HomeSectionInfo *homeSectionInfo;
@property (nonatomic, getter=isFeatured) BOOL featured;

@property (nonatomic, readonly, getter=isDataAvailable) BOOL dataAvailable;

@property (nonatomic) IBOutletCollection(NSLayoutConstraint) NSArray *leftSpacingConstraints;
@property (nonatomic, weak) IBOutlet UIView *headerView;
@property (nonatomic, weak) IBOutlet UIView *placeholderView;
@property (nonatomic, weak) IBOutlet UIImageView *placeholderImageView;

@property (nonatomic, weak) IBOutlet UILabel *titleLabel;
@property (nonatomic, weak) IBOutlet UIImageView *thumbnailImageView;

@property (nonatomic) IBOutletCollection(NSLayoutConstraint) NSArray *titleVerticalSpacingConstraints;

@end

@implementation HomeMediaCollectionHeaderView

#pragma mark Getters and setters

- (void)setLeftEdgeInset:(CGFloat)leftEdgeInset
{
    _leftEdgeInset = leftEdgeInset;
    
    for (NSLayoutConstraint *layoutConstraint in self.leftSpacingConstraints) {
        layoutConstraint.constant = leftEdgeInset;
    }
}

#pragma mark Overrides

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.backgroundColor = UIColor.clearColor;
    
    self.headerView.alpha = 0.f;
    self.placeholderView.alpha = 1.f;
    
    // Accommodate all kinds of usages (medium or small)
    self.placeholderImageView.image = [UIImage play_vectorImageAtPath:FilePathForImagePlaceholder(ImagePlaceholderMediaList)
                                                            withScale:ImageScaleMedium];
    
    self.thumbnailImageView.backgroundColor = UIColor.play_grayThumbnailImageViewBackgroundColor;
    
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openMediaList:)];
    [self.headerView addGestureRecognizer:tapGestureRecognizer];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    for (NSLayoutConstraint *layoutConstraint in self.titleVerticalSpacingConstraints) {
        layoutConstraint.constant = self.featured ? 8.f : 5.f;
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    
    [self.nearestViewController registerForPreviewingWithDelegate:self.nearestViewController sourceView:self];
}

#pragma mark Accessibility

- (BOOL)isAccessibilityElement
{
    return self.isDataAvailable;
}

- (NSString *)accessibilityLabel
{
    return [NSString stringWithFormat:PlaySRGAccessibilityLocalizedString(@"All content for \"%@\"", @"Title of the first cell of a media list on homepage."), self.homeSectionInfo.title];
}

- (UIAccessibilityTraits)accessibilityTraits
{
    return UIAccessibilityTraitButton;
}

- (CGRect)accessibilityFrame
{
    return UIAccessibilityConvertFrameToScreenCoordinates(self.headerView.frame, self);
}

#pragma mark Data

- (void)setHomeSectionInfo:(HomeSectionInfo *)homeSectionInfo featured:(BOOL)featured
{
    self.homeSectionInfo = homeSectionInfo;
    self.featured = featured;
    
    [self reloadData];
}

#pragma mark UI

- (BOOL)isDataAvailable
{
    return (self.homeSectionInfo.module || self.homeSectionInfo.topic);
}

- (void)reloadData
{
    if (! self.isDataAvailable) {
        self.headerView.alpha = 0.f;
        self.placeholderView.alpha = 1.f;
        return;
    }
    
    self.headerView.alpha = 1.f;
    self.placeholderView.alpha = 0.f;
    
    UIColor *titleTextColor = UIColor.whiteColor;
    UIColor *thumbnailImageViewBackgroundColor = UIColor.play_grayThumbnailImageViewBackgroundColor;
    if (self.homeSectionInfo.module && ! ApplicationConfiguration.sharedApplicationConfiguration.moduleColorsDisabled) {
        titleTextColor = self.homeSectionInfo.module.linkColor ?: ApplicationConfiguration.sharedApplicationConfiguration.moduleDefaultLinkColor;
        thumbnailImageViewBackgroundColor = [UIColor colorWithWhite:0.f alpha:0.1f];
    }
    
    self.titleLabel.textColor = titleTextColor;
    
    self.titleLabel.font = [UIFont srg_mediumFontWithTextStyle:self.featured ? SRGAppearanceFontTextStyleTitle : SRGAppearanceFontTextStyleBody];
    self.titleLabel.text = NSLocalizedString(@"All content", @"Title of the first cell of a media list on homepage.");
    
    self.thumbnailImageView.backgroundColor = thumbnailImageViewBackgroundColor;
    
    ImageScale imageScale = self.featured ? ImageScaleMedium : ImageScaleSmall;
    id<SRGImage> object = self.homeSectionInfo.module ?: self.homeSectionInfo.topic;
    [self.thumbnailImageView play_requestImageForObject:object withScale:imageScale type:SRGImageTypeDefault placeholder:ImagePlaceholderMediaList];
}

#pragma mark Previewing protocol

- (id)previewObject
{
    return self.homeSectionInfo.module ?: self.homeSectionInfo.topic;
}

#pragma mark Actions

- (IBAction)openMediaList:(id)sender
{
    if (! [self.homeSectionInfo canOpenList]) {
        return;
    }
    
    UIViewController *viewController = nil;
    if (self.homeSectionInfo.module) {
        viewController = [[ModuleViewController alloc] initWithModule:self.homeSectionInfo.module];
    }
    else if (self.homeSectionInfo.topic && [self.homeSectionInfo.topic isKindOfClass:SRGTopic.class]) {
        viewController = [[HomeTopicViewController alloc] initWithTopic:(SRGTopic *)self.homeSectionInfo.topic];
    }
    else {
        return;
    }
    [self.nearestViewController.navigationController pushViewController:viewController animated:YES];
}

@end
