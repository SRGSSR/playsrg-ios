//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "ProfilHeaderSectionView.h"

#import "NSBundle+PlaySRG.h"
#import "UIColor+PlaySRG.h"

#import <Masonry/Masonry.h>
#import <SRGAppearance/SRGAppearance.h>

@interface ProfilHeaderSectionView ()

@property (nonatomic, weak) IBOutlet UILabel *titleLabel;

@end

@implementation ProfilHeaderSectionView

#pragma mark Class methods

+ (CGFloat)heightForMenuSectionInfo:(MenuSectionInfo *)menuSectionInfo
{
    static CGFloat kStandardHeight = 64.f;
    
    if (menuSectionInfo.headerless) {
        return UIAccessibilityIsVoiceOverRunning() ? kStandardHeight : 10.f;
    }
    else {
        return kStandardHeight;
    }
}

#pragma mark Object lifecycle

- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
    if (self = [super initWithReuseIdentifier:reuseIdentifier]) {
        UIView *view = [[NSBundle.mainBundle loadNibNamed:NSStringFromClass(self.class) owner:self options:nil] firstObject];
        [self.contentView addSubview:view];
        [view mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self.contentView);
        }];
        
        // Setting the background view installs it in the view hierarchy
        self.backgroundView = [[UIView alloc] initWithFrame:self.bounds];
        self.backgroundView.backgroundColor = UIColor.blackColor;
        [self.backgroundView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self);
        }];
        
        // Force usual behavior (otherwise not triggered).
        [self awakeFromNib];
    }
    return self;
}

#pragma mark Overrides

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    UIColor *backgroundColor = UIColor.blackColor;
    self.contentView.backgroundColor = backgroundColor;
    
    self.titleLabel.backgroundColor = backgroundColor;
    self.titleLabel.textColor = UIColor.play_lightGrayColor;
}

#pragma mark Getters and setters

- (void)setMenuSectionInfo:(MenuSectionInfo *)menuSectionInfo
{
    _menuSectionInfo = menuSectionInfo;
    
    if (menuSectionInfo.headerless) {
        self.titleLabel.text = UIAccessibilityIsVoiceOverRunning() ? menuSectionInfo.title : nil;
    }
    else {
        self.titleLabel.text = menuSectionInfo.title;
    }
    
    self.titleLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleTitle];
}

#pragma mark Accessibility

- (NSString *)accessibilityLabel
{
    return self.menuSectionInfo.title;
}

@end
