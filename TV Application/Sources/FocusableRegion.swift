//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import SwiftUI

/**
 *  A region which can capture the focus, no matter the focus comes from.
 */
struct FocusableRegion<Content: View>: UIViewControllerRepresentable {
    private let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    func makeUIViewController(context: Context) -> UIHostingController<Content> {
        let hostController = UIHostingController(rootView: content(), ignoreSafeArea: true)
        
        if let hostView = hostController.view {
            let focusGuide = UIFocusGuide()
            focusGuide.preferredFocusEnvironments = [hostView]
            hostView.addLayoutGuide(focusGuide)
            
            NSLayoutConstraint.activate([
                focusGuide.topAnchor.constraint(equalTo: hostView.topAnchor),
                focusGuide.bottomAnchor.constraint(equalTo: hostView.bottomAnchor),
                focusGuide.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
                focusGuide.trailingAnchor.constraint(equalTo: hostView.trailingAnchor)
            ])
        }
        
        return hostController
    }
    
    func updateUIViewController(_ uiViewController: UIHostingController<Content>, context: Context) {
        uiViewController.rootView = content()
    }
}
