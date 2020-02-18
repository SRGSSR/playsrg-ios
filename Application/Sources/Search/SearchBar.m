//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SearchBar.h"

__attribute__((constructor)) static void SearchBarInit(void)
{
    [UIBarButtonItem appearanceWhenContainedInInstancesOfClasses:@[ SearchBar.class ]].tintColor = UIColor.whiteColor;
}

@implementation SearchBar

@end
