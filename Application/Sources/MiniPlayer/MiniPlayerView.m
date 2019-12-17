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
#import <Masonry/Masonry.h>

@interface MiniPlayerView ()

@property (nonatomic, weak) PlayMiniPlayerView *audioMiniPlayerView;
@property (nonatomic, weak) GoogleCastMiniPlayerView *googleCastMiniPlayerView;
@property (nonatomic, getter=isActive) BOOL active;

@end

@implementation MiniPlayerView

#pragma mark Object lifecycle

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        UIVisualEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        [self addSubview:blurView];
        
        [blurView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self);
        }];
        
        PlayMiniPlayerView *audioMiniPlayerView = PlayMiniPlayerView.view;
        [self addSubview:audioMiniPlayerView];
        [audioMiniPlayerView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self);
        }];
        self.audioMiniPlayerView = audioMiniPlayerView;
        
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
    BOOL hasRadioChannels = ApplicationConfiguration.sharedApplicationConfiguration.radioChannels.count != 0;
    
    self.active = isGoogleCastConnected || hasRadioChannels;
    
    void (^animations)(void) = ^{
        if (isGoogleCastConnected) {
            self.audioMiniPlayerView.alpha = 0.f;
            self.googleCastMiniPlayerView.alpha = 1.f;
        }
        else if (hasRadioChannels) {
            self.audioMiniPlayerView.alpha = 1.f;
            self.googleCastMiniPlayerView.alpha = 0.f;
        }
        else {
            self.audioMiniPlayerView.alpha = 0.f;
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
