//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "Layout.h"

CGFloat LayoutCollectionItemOptimalWidth(CGFloat itemApproximateWidth, CGFloat layoutWidth, CGFloat leadingInset, CGFloat trailingInset, CGFloat spacing)
{
    CGFloat availableWidth = layoutWidth - leadingInset - trailingInset;
    if (availableWidth <= 0.f) {
        return 0.f;
    }
    
    // For a grid, two items are required at least
    NSInteger numberOfItemsPerRow = MAX((availableWidth + spacing) / (itemApproximateWidth + spacing), 2);
    return (availableWidth - (numberOfItemsPerRow - 1) * spacing) / numberOfItemsPerRow;
}

CGFloat LayoutCollectionItemFeaturedWidth(CGFloat layoutWidth)
{
    // Ensure cells never fill the entire width of the parent, so that the fact that content can be scrolled
    // is always obvious to the user
    static const CGFloat kHorizontalFillRatio = 0.9f;
    
    // Do not make cells unnecessarily large
    UITraitCollection *traitCollection = UIApplication.sharedApplication.keyWindow.traitCollection;
    CGFloat maxWidth = (traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact) ? 300.f : 450.f;
    
    return fmin(layoutWidth * kHorizontalFillRatio, maxWidth);
}

CGFloat LayoutStandardTableSectionHeaderHeight(BOOL hasBackgroundColor)
{
    static NSDictionary<UIContentSizeCategory, NSNumber *> *s_headerHeights;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        s_headerHeights = @{ UIContentSizeCategoryExtraSmall : @25,
                             UIContentSizeCategorySmall : @30,
                             UIContentSizeCategoryMedium : @35,
                             UIContentSizeCategoryLarge : @35,
                             UIContentSizeCategoryExtraLarge : @35,
                             UIContentSizeCategoryExtraExtraLarge : @35,
                             UIContentSizeCategoryExtraExtraExtraLarge : @40,
                             UIContentSizeCategoryAccessibilityMedium : @40,
                             UIContentSizeCategoryAccessibilityLarge : @40,
                             UIContentSizeCategoryAccessibilityExtraLarge : @40,
                             UIContentSizeCategoryAccessibilityExtraExtraLarge : @40,
                             UIContentSizeCategoryAccessibilityExtraExtraExtraLarge : @40 };
    });
    
    UIContentSizeCategory contentSizeCategory = UIApplication.sharedApplication.preferredContentSizeCategory;
    CGFloat headerHeight = s_headerHeights[contentSizeCategory].floatValue;
    if (hasBackgroundColor) {
        headerHeight += 6.f;
    }
    return headerHeight;
}

CGFloat LayoutStandardSimpleTableCellHeight(void)
{
    static NSDictionary<UIContentSizeCategory, NSNumber *> *s_heights;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        s_heights = @{ UIContentSizeCategoryExtraSmall : @42,
                       UIContentSizeCategorySmall : @42,
                       UIContentSizeCategoryMedium : @46,
                       UIContentSizeCategoryLarge : @50,
                       UIContentSizeCategoryExtraLarge : @54,
                       UIContentSizeCategoryExtraExtraLarge : @58,
                       UIContentSizeCategoryExtraExtraExtraLarge : @62,
                       UIContentSizeCategoryAccessibilityMedium : @62,
                       UIContentSizeCategoryAccessibilityLarge : @62,
                       UIContentSizeCategoryAccessibilityExtraLarge : @62,
                       UIContentSizeCategoryAccessibilityExtraExtraLarge : @62,
                       UIContentSizeCategoryAccessibilityExtraExtraExtraLarge : @62 };
    });
    UIContentSizeCategory contentSizeCategory = UIApplication.sharedApplication.preferredContentSizeCategory;
    return s_heights[contentSizeCategory].floatValue;
}

CGFloat LayoutTableTopAlignedCellHeight(CGFloat contentHeight, CGFloat spacing, NSInteger row, NSInteger numberOfItems)
{
    if (row < numberOfItems - 1) {
        return contentHeight + spacing;
    }
    else {
        return contentHeight;
    }
}

CGSize LayoutMediaStandardCollectionItemSize(CGFloat itemWidth, BOOL large)
{
    static NSDictionary<UIContentSizeCategory, NSNumber *> *s_largeTextHeights;
    static NSDictionary<UIContentSizeCategory, NSNumber *> *s_standardTextHeights;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        s_largeTextHeights = @{ UIContentSizeCategoryExtraSmall : @79,
                                UIContentSizeCategorySmall : @81,
                                UIContentSizeCategoryMedium : @84,
                                UIContentSizeCategoryLarge : @89,
                                UIContentSizeCategoryExtraLarge : @94,
                                UIContentSizeCategoryExtraExtraLarge : @102,
                                UIContentSizeCategoryExtraExtraExtraLarge : @108,
                                UIContentSizeCategoryAccessibilityMedium : @108,
                                UIContentSizeCategoryAccessibilityLarge : @108,
                                UIContentSizeCategoryAccessibilityExtraLarge : @108,
                                UIContentSizeCategoryAccessibilityExtraExtraLarge : @108,
                                UIContentSizeCategoryAccessibilityExtraExtraExtraLarge : @108 };
        
        s_standardTextHeights = @{ UIContentSizeCategoryExtraSmall : @63,
                                   UIContentSizeCategorySmall : @65,
                                   UIContentSizeCategoryMedium : @67,
                                   UIContentSizeCategoryLarge : @70,
                                   UIContentSizeCategoryExtraLarge : @75,
                                   UIContentSizeCategoryExtraExtraLarge : @82,
                                   UIContentSizeCategoryExtraExtraExtraLarge : @90,
                                   UIContentSizeCategoryAccessibilityMedium : @90,
                                   UIContentSizeCategoryAccessibilityLarge : @90,
                                   UIContentSizeCategoryAccessibilityExtraLarge : @90,
                                   UIContentSizeCategoryAccessibilityExtraExtraLarge : @90,
                                   UIContentSizeCategoryAccessibilityExtraExtraExtraLarge : @90 };
    });
    
    UIContentSizeCategory contentSizeCategory = UIApplication.sharedApplication.preferredContentSizeCategory;
    CGFloat minTextHeight = large ? s_largeTextHeights[contentSizeCategory].floatValue : s_standardTextHeights[contentSizeCategory].floatValue;
    return CGSizeMake(itemWidth, ceilf(itemWidth * 9.f / 16.f + minTextHeight));
}

CGSize LayoutLiveMediaStandardCollectionItemSize(CGFloat itemWidth)
{
    return CGSizeMake(itemWidth, ceilf(itemWidth * 9.f / 16.f + 11.f));
}

CGSize LayoutShowStandardCollectionItemSize(CGFloat itemWidth, BOOL large)
{
    static NSDictionary<UIContentSizeCategory, NSNumber *> *s_largeTextHeights;
    static NSDictionary<UIContentSizeCategory, NSNumber *> *s_standardTextHeights;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        s_largeTextHeights = @{ UIContentSizeCategoryExtraSmall : @28,
                                UIContentSizeCategorySmall : @28,
                                UIContentSizeCategoryMedium : @29,
                                UIContentSizeCategoryLarge : @31,
                                UIContentSizeCategoryExtraLarge : @33,
                                UIContentSizeCategoryExtraExtraLarge : @36,
                                UIContentSizeCategoryExtraExtraExtraLarge : @38,
                                UIContentSizeCategoryAccessibilityMedium : @38,
                                UIContentSizeCategoryAccessibilityLarge : @38,
                                UIContentSizeCategoryAccessibilityExtraLarge : @38,
                                UIContentSizeCategoryAccessibilityExtraExtraLarge : @38,
                                UIContentSizeCategoryAccessibilityExtraExtraExtraLarge : @38 };
        
        s_standardTextHeights = @{ UIContentSizeCategoryExtraSmall : @26,
                                   UIContentSizeCategorySmall : @26,
                                   UIContentSizeCategoryMedium : @27,
                                   UIContentSizeCategoryLarge : @29,
                                   UIContentSizeCategoryExtraLarge : @31,
                                   UIContentSizeCategoryExtraExtraLarge : @34,
                                   UIContentSizeCategoryExtraExtraExtraLarge : @36,
                                   UIContentSizeCategoryAccessibilityMedium : @36,
                                   UIContentSizeCategoryAccessibilityLarge : @36,
                                   UIContentSizeCategoryAccessibilityExtraLarge : @36,
                                   UIContentSizeCategoryAccessibilityExtraExtraLarge : @36,
                                   UIContentSizeCategoryAccessibilityExtraExtraExtraLarge : @36 };
    });
    
    UIContentSizeCategory contentSizeCategory = UIApplication.sharedApplication.preferredContentSizeCategory;
    CGFloat minTextHeight = large ? s_largeTextHeights[contentSizeCategory].floatValue : s_standardTextHeights[contentSizeCategory].floatValue;
    return CGSizeMake(itemWidth, ceilf(itemWidth * 9.f / 16.f + minTextHeight));
}
