//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import TvOSTextViewer
import SwiftUI

func navigateToMedia(_ media: SRGMedia, play: Bool = false, animated: Bool = true) {
    guard let topViewController = UIApplication.shared.keyWindow?.topViewController else { return }
    
    if !play && media.contentType != .livestream {
        let hostController = UIHostingController(rootView: MediaDetailView(media: media))
        topViewController.present(hostController, animated: animated, completion: nil)
    }
    else {
        let letterboxViewController = SRGLetterboxViewController()
        
        applyLetterboxControllerSettings(to: letterboxViewController.controller)
        
        letterboxViewController.controller.playMedia(media, at: nil, withPreferredSettings: nil)
        topViewController.present(letterboxViewController, animated: animated, completion: nil)
    }
}

func navigateToShow(_ show: SRGShow, animated: Bool = true) {
    guard let topViewController = UIApplication.shared.keyWindow?.topViewController else { return }
    
    let hostController = UIHostingController(rootView: ShowDetailView(show: show))
    topViewController.present(hostController, animated: animated, completion: nil)
}

func navigateToTopic(_ topic: SRGTopic, animated: Bool = true) {
    guard let topViewController = UIApplication.shared.keyWindow?.topViewController else { return }
    
    let hostController = UIHostingController(rootView: TopicDetailView(topic: topic))
    topViewController.present(hostController, animated: animated, completion: nil)
}

func showText(_ text: String, animated: Bool = true) {
    guard let topViewController = UIApplication.shared.keyWindow?.topViewController else { return }
    
    let textViewController = TvOSTextViewerViewController()
    textViewController.text = text
    textViewController.textAttributes = [.foregroundColor: UIColor.white,
                                         .font: UIFont.srg_regularFont(withTextStyle: .subtitle)]
    textViewController.textEdgeInsets = UIEdgeInsets(top: 100, left: 250, bottom: 100, right: 250)
    textViewController.modalPresentationStyle = .overFullScreen
    topViewController.present(textViewController, animated: animated)
}

fileprivate func applyLetterboxControllerSettings(to controller: SRGLetterboxController) {
    controller.serviceURL = SRGDataProvider.current?.serviceURL
    controller.globalParameters = SRGDataProvider.current?.globalParameters
    
    let applicationConfiguration = ApplicationConfiguration.shared
    controller.endTolerance = applicationConfiguration.endTolerance;
    controller.endToleranceRatio = applicationConfiguration.endToleranceRatio;
}