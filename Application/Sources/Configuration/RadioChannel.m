//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "RadioChannel.h"

#import "UIColor+PlaySRG.h"

#import <SRGAppearance/SRGAppearance.h>

@interface RadioChannel ()

@property (nonatomic, copy) NSString *uid;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *resourceUid;      // Local unique identifier for referencing resources in a common way
@property (nonatomic) UIColor *color;
@property (nonatomic) UIColor *titleColor;
@property (nonatomic, getter=hasDarkStatusBar) BOOL darkStatusBar;
@property (nonatomic, getter=isBadgeStrokeHidden) BOOL badgeStrokeHidden;
@property (nonatomic) NSInteger numberOfLivePlaceholders;
@property (nonatomic) NSArray<NSNumber *> *homeSections;

@end

@implementation RadioChannel

#pragma Object lifecycle

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    if (self = [super init]) {
        self.uid = dictionary[@"uid"];
        if (! [self.uid isKindOfClass:NSString.class]) {
            return nil;
        }
        
        self.name = dictionary[@"name"];
        if (! [self.name isKindOfClass:NSString.class]) {
            return nil;
        }
        
        self.resourceUid = dictionary[@"resourceUid"];
        if (! [self.resourceUid isKindOfClass:NSString.class]) {
            return nil;
        }
        
        id colorValue = dictionary[@"color"];
        if (! [colorValue isKindOfClass:NSString.class]) {
            return nil;
        }
        
        self.color = [UIColor srg_colorFromHexadecimalString:colorValue];
        if (! self.color) {
            return nil;
        }
        
        self.homeSections = dictionary[@"homeSections"];
        if (! [self.homeSections isKindOfClass:NSArray.class] || self.homeSections.count == 0) {
            return nil;
        }
        
        id titleColorValue = dictionary[@"titleColor"];
        if ([titleColorValue isKindOfClass:NSString.class]) {
            self.titleColor = [UIColor srg_colorFromHexadecimalString:titleColorValue] ?: UIColor.whiteColor;
        }
        else {
            self.titleColor = UIColor.whiteColor;
        }
        
        id darkStatusBarValue = dictionary[@"hasDarkStatusBar"];
        if ([darkStatusBarValue isKindOfClass:NSNumber.class]) {
            self.darkStatusBar = [darkStatusBarValue boolValue];
        }
        
        id badgeStrokeHiddenValue = dictionary[@"badgeStrokeHidden"];
        if ([badgeStrokeHiddenValue isKindOfClass:NSNumber.class]) {
            self.badgeStrokeHidden = [badgeStrokeHiddenValue boolValue];
        }
        
        id numberOfLivePlaceholdersValue = dictionary[@"numberOfLivePlaceholders"];
        if ([numberOfLivePlaceholdersValue isKindOfClass:NSNumber.class]) {
            self.numberOfLivePlaceholders = [numberOfLivePlaceholdersValue integerValue];
        }
        else {
            self.numberOfLivePlaceholders = 1;
        }
    }
    return self;
}

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return [self initWithDictionary:@{}];
}

#pragma mark - Object identity

- (BOOL)isEqual:(id)object
{
    if (self == object) {
        return YES;
    }
    
    if (! [object isKindOfClass:self.class]) {
        return NO;
    }
    
    return [self.uid isEqualToString:[object uid]];
}

- (NSUInteger)hash
{
    return self.uid.hash;
}

#pragma mark Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; uid = %@; name = %@>",
            self.class,
            self,
            self.uid,
            self.name];
}

@end

UIImage *RadioChannelBanner22Image(RadioChannel *radioChannel)
{
    return [UIImage imageNamed:[NSString stringWithFormat:@"banner_%@-22", radioChannel.resourceUid]] ?: RadioChannelLogo22Image(radioChannel);
}

UIImage *RadioChannelLogo22Image(RadioChannel *radioChannel)
{
    return [UIImage imageNamed:[NSString stringWithFormat:@"logo_%@-22", radioChannel.resourceUid]] ?: [UIImage imageNamed:@"radioset-22"];
}

NSString *RadioChannelImageOverridePath(RadioChannel *radioChannel, NSString *type)
{
    NSString *overrideImageName = [NSString stringWithFormat:@"override_%@_%@", type, radioChannel.resourceUid];
    return [NSBundle.mainBundle pathForResource:overrideImageName ofType:@"pdf"];
}
