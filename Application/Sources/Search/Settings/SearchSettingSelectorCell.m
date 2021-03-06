//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SearchSettingSelectorCell.h"

#import "UIColor+PlaySRG.h"

@import SRGAppearance;

@interface SearchSettingSelectorCell ()

@property (nonatomic, weak) IBOutlet UILabel *nameLabel;

@end

@implementation SearchSettingSelectorCell

#pragma mark Getters and setters

- (void)setName:(NSString *)name
{
    _name = name;
    
    self.nameLabel.font = [UIFont srg_regularFontWithTextStyle:SRGAppearanceFontTextStyleBody];
    self.nameLabel.text = name;
}

#pragma mark Overrides

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.backgroundColor = UIColor.play_popoverGrayBackgroundColor;
    
    self.tintColor = UIColor.whiteColor;
    self.nameLabel.textColor = UIColor.whiteColor;
    
    self.selectionStyle = UITableViewCellSelectionStyleNone;
}

@end
