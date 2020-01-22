//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "GoogleCastBarButtonItem.h"

#import <GoogleCast/GoogleCast.h>
#import <libextobjc/libextobjc.h>
#import <MAKVONotificationCenter/MAKVONotificationCenter.h>

@interface GoogleCastBarButtonItem ()

@property (nonatomic) GCKUICastButton *castButton;
@property (nonatomic, weak) UINavigationBar *navigationBar;

@end

@implementation GoogleCastBarButtonItem

#pragma mark Object lifecycle

- (instancetype)initForNavigationBar:(UINavigationBar *)navigationBar
{
    GCKUICastButton *castButton = [[GCKUICastButton alloc] initWithFrame:CGRectMake(0.f, 0.f, 44.f, 44.f)];
    if (self = [super initWithCustomView:castButton]) {
        self.castButton = castButton;
        self.navigationBar = navigationBar;
        
        @weakify(self)
        [navigationBar addObserver:self keyPath:@keypath(navigationBar.tintColor) options:0 block:^(MAKVONotification *notification) {
            @strongify(self)
            [self updateAppearance];
        }];
        [self updateAppearance];
    }
    return self;
}

#pragma mark Updates

- (void)updateAppearance
{
    self.castButton.tintColor = self.navigationBar.tintColor;
}

@end
