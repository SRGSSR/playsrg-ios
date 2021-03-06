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
        HomeSectionInfo *subtopicSectionInfo = [[HomeSectionInfo alloc] initWithHomeSection:HomeSectionTVTopics object:subtopic];
        subtopicSectionInfo.title = subtopic.title;
        subtopicSectionInfo.parentTitle = topic.title;
        [viewControllers addObject:[[HomeMediasViewController alloc] initWithHomeSectionInfo:subtopicSectionInfo]];
    }
    
    if (self = [super initWithViewControllers:viewControllers.copy]) {
        self.title = topic.title;
    }
    return self;
}

@end
