//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "LibraryHeaderSectionView.h"

#import "NSBundle+PlaySRG.h"
#import "UIColor+PlaySRG.h"

#import <Masonry/Masonry.h>
#import <SRGAppearance/SRGAppearance.h>

@interface LibraryHeaderSectionView ()

@property (nonatomic, weak) IBOutlet UILabel *titleLabel;

@end

@implementation LibraryHeaderSectionView

#pragma mark Class methods

+ (CGFloat)heightForApplicationSectionGroup:(ApplicationSectionGroup *)applicationSectionGroup
{
    return UIAccessibilityIsVoiceOverRunning() ? 64.f : 10.f;
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
        self.backgroundView.backgroundColor = UIColor.play_blackColor;
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
    
    UIColor *backgroundColor = UIColor.play_blackColor;
    self.contentView.backgroundColor = backgroundColor;
    
    self.titleLabel.backgroundColor = backgroundColor;
    self.titleLabel.textColor = UIColor.whiteColor;
}

#pragma mark Getters and setters

- (void)setApplicationSectionGroup:(ApplicationSectionGroup *)applicationSectionInfo
{
    _applicationSectionGroup = applicationSectionInfo;
    
    self.titleLabel.text = UIAccessibilityIsVoiceOverRunning() ? applicationSectionInfo.title : nil;
    self.titleLabel.font = [UIFont srg_mediumFontWithTextStyle:SRGAppearanceFontTextStyleTitle];
}

#pragma mark Accessibility

- (NSString *)accessibilityLabel
{
    return self.applicationSectionGroup.title;
}

@end
