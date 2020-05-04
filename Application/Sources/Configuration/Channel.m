//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "Channel.h"

#import <SRGAppearance/SRGAppearance.h>

@interface Channel ()

@property (nonatomic, copy) NSString *uid;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *resourceUid;
@property (nonatomic) UIColor *color;
@property (nonatomic) UIColor *color2;
@property (nonatomic) UIColor *titleColor;

@end

@implementation Channel

#pragma mark Object lifecycle

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
        if ([colorValue isKindOfClass:NSString.class]) {
            self.color = [UIColor srg_colorFromHexadecimalString:colorValue] ?: UIColor.grayColor;
        }
        else {
            self.color = UIColor.grayColor;
        }
        
        id color2Value = dictionary[@"color2"];
        if ([color2Value isKindOfClass:NSString.class]) {
            self.color2 = [UIColor srg_colorFromHexadecimalString:color2Value] ?: self.color;
        }
        else {
            self.color2 = self.color;
        }
        
        id titleColorValue = dictionary[@"titleColor"];
        if ([titleColorValue isKindOfClass:NSString.class]) {
            self.titleColor = [UIColor srg_colorFromHexadecimalString:titleColorValue] ?: UIColor.whiteColor;
        }
        else {
            self.titleColor = UIColor.whiteColor;
        }
    }
    return self;
}

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return [self initWithDictionary:@{}];
}

#pragma mark Object identity

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
