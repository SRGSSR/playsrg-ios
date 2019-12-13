//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "HomeShowCollectionViewCell.h"

#import "NSBundle+PlaySRG.h"
#import "UIColor+PlaySRG.h"
#import "UIImageView+PlaySRG.h"

#import <SRGAppearance/SRGAppearance.h>

@interface HomeShowCollectionViewCell ()

@property (nonatomic) SRGShow *show;
@property (nonatomic, getter=isFeatured) BOOL featured;

@property (nonatomic, weak) IBOutlet UIView *showView;
@property (nonatomic, weak) IBOutlet UIView *placeholderView;
@property (nonatomic, weak) IBOutlet UIImageView *placeholderImageView;

@property (nonatomic, weak) IBOutlet UIImageView *thumbnailImageView;
@property (nonatomic, weak) IBOutlet UILabel *titleLabel;

@property (nonatomic) IBOutletCollection(NSLayoutConstraint) NSArray *titleVerticalSpacingConstraints;

@end

@implementation HomeShowCollectionViewCell

#pragma mark Overrides

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.backgroundColor = UIColor.clearColor;
    
    self.showView.hidden = YES;
    self.placeholderView.hidden = NO;
    
    // Accommodate all kinds of usages (medium or small)
    self.placeholderImageView.image = [UIImage play_vectorImageAtPath:FilePathForImagePlaceholder(ImagePlaceholderMediaList)
                                                            withScale:ImageScaleMedium];
    
    self.thumbnailImageView.backgroundColor = UIColor.play_grayThumbnailImageViewBackgroundColor;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    self.show = nil;
    
    self.featured = NO;
    
    self.showView.hidden = YES;
    self.placeholderView.hidden = NO;
    
    [self.thumbnailImageView play_resetImage];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    for (NSLayoutConstraint *layoutConstraint in self.titleVerticalSpacingConstraints) {
        layoutConstraint.constant = self.featured ? 8.f : 5.f;
    }
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    
    [self play_registerForPreview];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    
    [self play_registerForPreview];
}

#pragma mark Accessibility

- (BOOL)isAccessibilityElement
{
    return self.show != nil;
}

- (NSString *)accessibilityLabel
{
    return self.show.title;
}

- (NSString *)accessibilityHint
{
    return PlaySRGAccessibilityLocalizedString(@"Opens show details.", @"Show cell hint");
}

#pragma mark Data

- (void)setShow:(SRGShow *)show featured:(BOOL)featured
{
    self.show = show;
    self.featured = featured;
    
    [self reloadData];
}

#pragma mark UI

- (void)reloadData
{
    if (! self.show) {
        self.showView.hidden = YES;
        self.placeholderView.hidden = NO;
        return;
    }
    
    self.showView.hidden = NO;
    self.placeholderView.hidden = YES;
    
    self.titleLabel.font = [UIFont srg_mediumFontWithTextStyle:self.featured ? SRGAppearanceFontTextStyleTitle : SRGAppearanceFontTextStyleBody];
    
    self.titleLabel.text = self.show.title;
    
    ImageScale imageScale = self.featured ? ImageScaleMedium : ImageScaleSmall;
    [self.thumbnailImageView play_requestImageForObject:self.show withScale:imageScale type:SRGImageTypeDefault placeholder:ImagePlaceholderMediaList];
}

#pragma mark Previewing protocol

- (id)previewObject
{
    return self.show;
}

- (NSValue *)previewAnchorRect
{
    CGRect imageViewFrameInSelf = [self.thumbnailImageView convertRect:self.thumbnailImageView.bounds toView:self];
    return [NSValue valueWithCGRect:imageViewFrameInSelf];
}

@end
