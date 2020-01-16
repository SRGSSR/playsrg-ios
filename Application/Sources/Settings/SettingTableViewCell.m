//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SettingTableViewCell.h"

#import "UIColor+PlaySRG.h"

@implementation SettingTableViewCell

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    self.textLabel.textColor = highlighted ? UIColor.play_grayColor : UIColor.whiteColor;
}

@end
