//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "MiniPlayerView.h"

#import "ApplicationConfiguration.h"
#import "PlayMiniPlayerView.h"
#import "GoogleCastMiniPlayerView.h"
#import "UIColor+PlaySRG.h"

#import <GoogleCast/GoogleCast.h>
#import <libextobjc/libextobjc.h>
#import <MAKVONotificationCenter/MAKVONotificationCenter.h>
#import <Masonry/Masonry.h>

@interface MiniPlayerView ()

@property (nonatomic, weak) PlayMiniPlayerView *playMiniPlayerView;
@property (nonatomic, weak) GoogleCastMiniPlayerView *googleCastMiniPlayerView;
@property (nonatomic, getter=isActive) BOOL active;

@end

@implementation MiniPlayerView

#pragma mark Object lifecycle

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        UIBlurEffectStyle blurEffectStyle;
        if (@available(iOS 13, *)) {
            blurEffectStyle = UIBlurEffectStyleSystemMaterialDark;
        }
        else {
            blurEffectStyle = UIBlurEffectStyleDark;
        }
        UIVisualEffect *blurEffect = [UIBlurEffect effectWithStyle:blurEffectStyle];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        [self addSubview:blurView];
        
        [blurView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self);
        }];
        
        PlayMiniPlayerView *playMiniPlayerView = PlayMiniPlayerView.view;
        [self addSubview:playMiniPlayerView];
        [playMiniPlayerView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self);
        }];
        self.playMiniPlayerView = playMiniPlayerView;
        
        @weakify(self)
        [self.playMiniPlayerView addObserver:self keyPath:@keypath(PlayMiniPlayerView.new, media) options:0 block:^(MAKVONotification *notification) {
            @strongify(self)
            [self updateLayoutAnimated:YES];
        }];
        
        GoogleCastMiniPlayerView *googleCastMiniPlayerView = GoogleCastMiniPlayerView.view;
        [self addSubview:googleCastMiniPlayerView];
        [googleCastMiniPlayerView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self);
        }];
        self.googleCastMiniPlayerView = googleCastMiniPlayerView;
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(googleCastStateDidChange:)
                                                   name:kGCKCastStateDidChangeNotification
                                                 object:nil];
        
        self.layer.cornerRadius = 4.f;
        self.layer.masksToBounds = YES;
        
        [self updateLayoutAnimated:NO];
    }
    return self;
}

#pragma mark Subview management

- (void)updateLayoutAnimated:(BOOL)animated
{
    BOOL isGoogleCastConnected = [GCKCastContext sharedInstance].sessionManager.connectionState == GCKConnectionStateConnected;
    BOOL hasMedia = self.playMiniPlayerView.media != nil;
    
    self.active = isGoogleCastConnected || hasMedia;
    
    void (^animations)(void) = ^{
        if (isGoogleCastConnected) {
            self.playMiniPlayerView.alpha = 0.f;
            self.googleCastMiniPlayerView.alpha = 1.f;
        }
        else if (hasMedia) {
            self.playMiniPlayerView.alpha = 1.f;
            self.googleCastMiniPlayerView.alpha = 0.f;
        }
        else {
            self.playMiniPlayerView.alpha = 0.f;
            self.googleCastMiniPlayerView.alpha = 0.f;
        }
    };
    
    if (animated) {
        [UIView animateWithDuration:0.2 animations:animations];
    }
    else {
        animations();
    }
}

#pragma mark Notifications

- (void)googleCastStateDidChange:(NSNotification *)notification
{
    [self updateLayoutAnimated:YES];
}

@end
