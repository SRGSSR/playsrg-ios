//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "UIDevice+PlaySRG.h"

#import <sys/utsname.h>

static BOOL s_locked = NO;

// Function declarations
static void lockComplete(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);

@implementation UIDevice (PlaySRG)

#pragma mark Class methods

#pragma mark Class methods

+ (BOOL)play_isLocked
{
    return s_locked;
}

+ (BOOL)play_isLandscape
{
    UIDeviceOrientation deviceOrientation = UIDevice.currentDevice.orientation;
    return UIDeviceOrientationIsValidInterfaceOrientation(deviceOrientation) ? UIDeviceOrientationIsLandscape(deviceOrientation) : UIInterfaceOrientationIsLandscape(UIApplication.sharedApplication.statusBarOrientation);
}

#pragma mark Notifications

+ (void)play_applicationDidBecomeActive:(NSNotification *)notification
{
    s_locked = NO;
}

@end

#pragma mark Functions

__attribute__((constructor)) static void SRGLetterboxUIDeviceInit(void)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // Differentiate between device lock and application sent to the background
        // See http://stackoverflow.com/a/9058038/760435
        NSString *notification = [[[NSString stringWithFormat:@"122c1o6m7.a8p93p0l99e8.s65p4r43i32ng2b1234o2a432rd.l23o3c25567k8c9o08m65p43l32e2te"] componentsSeparatedByCharactersInSet:NSCharacterSet.decimalDigitCharacterSet] componentsJoinedByString:@""];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        (__bridge const void *)UIDevice.class,
                                        lockComplete,
                                        (__bridge CFStringRef)notification,
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        
        [NSNotificationCenter.defaultCenter addObserver:UIDevice.class
                                               selector:@selector(play_applicationDidBecomeActive:)
                                                   name:UIApplicationDidBecomeActiveNotification
                                                 object:nil];
    });
}

static void lockComplete(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    s_locked = YES;
}

