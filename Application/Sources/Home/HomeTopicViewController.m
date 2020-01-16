//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "HomeTopicViewController.h"

#import "ApplicationConfiguration.h"
#import "HomeMediasViewController.h"

@implementation HomeTopicViewController

#pragma mark Object lifecycle

- (instancetype)initWithTopic:(SRGTopic *)topic
{
    NSMutableArray<UIViewController *> *viewControllers = [NSMutableArray array];
    
    NSArray<NSNumber *> *topicSections = nil;
    if (topic.subtopics.count != 0) {
        topicSections = ApplicationConfiguration.sharedApplicationConfiguration.topicSectionsWithSubtopics;
    }
    else {
        topicSections = ApplicationConfiguration.sharedApplicationConfiguration.topicSections;
        
        if (topicSections.count == 0) {
            topicSections = @[@(TopicSectionLatest)];
        }
    }
    
    for (NSNumber *topicSection in topicSections) {
        if (topicSection != TopicSectionUnknown) {
            HomeSectionInfo *topicSectionInfo = [[HomeSectionInfo alloc] initWithHomeSection:HomeSectionTVTopics topicSection:topicSection.integerValue object:topic];
            [viewControllers addObject:[[HomeMediasViewController alloc] initWithHomeSectionInfo:topicSectionInfo]];
        }
    }
    
    for (SRGSubtopic *subtopic in topic.subtopics) {
        HomeSectionInfo *subTopicSectionInfo = [[HomeSectionInfo alloc] initWithHomeSection:HomeSectionTVTopics object:subtopic];
        subTopicSectionInfo.title = subtopic.title;
        [viewControllers addObject:[[HomeMediasViewController alloc] initWithHomeSectionInfo:subTopicSectionInfo]];
    }
    
    if (self = [super initWithViewControllers:viewControllers.copy]) {
        self.title = topic.title;
    }
    return self;
}

#pragma mark SRGAnalyticsViewTracking protocol

- (NSString *)srg_pageViewTitle
{
    return self.title;
}

- (NSArray<NSString *> *)srg_pageViewLevels
{
    return @[ AnalyticsNameForPageType(AnalyticsPageTypeTV) ];
}

@end
