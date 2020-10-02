//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import SRGAppearance
import SRGLetterbox
import SwiftUI

struct MediaCell: View {
    private struct DescriptionView: View {
        let media: SRGMedia?
        
        var body: some View {
            Text(MediaDescription.title(for: media))
                .srgFont(.medium, size: .subtitle)
                .lineLimit(2)
            Text(MediaDescription.subtitle(for: media))
                .srgFont(.light, size: .subtitle)
                .lineLimit(2)
        }
    }
    
    let media: SRGMedia?
    
    @State var isFocused: Bool = false
    
    private var redactionReason: RedactionReasons {
        return media == nil ? .placeholder : .init()
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Button(action: {
                    // TODO: Could / should be presented with SwiftUI, but presentation flag must be part of topmost state
                    if let media = media,
                       let rootViewController = UIApplication.shared.windows.first?.rootViewController {
                        let letterboxViewController = SRGLetterboxViewController()
                        letterboxViewController.controller.playMedia(media, at: nil, withPreferredSettings: nil)
                        rootViewController.present(letterboxViewController, animated: true, completion: nil)
                    }
                }) {
                    MediaVisual(media: media, scale: .small, contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.width * 9 / 16)
                        .reportFocusChanges()
                }
                .buttonStyle(CardButtonStyle())
                
                DescriptionView(media: media)
                    .frame(width: geometry.size.width, alignment: .leading)
                    .opacity(isFocused ? 1 : 0.5)
                    .offset(x: 0, y: isFocused ? 10 : 0)
                    .scaleEffect(isFocused ? 1.1 : 1, anchor: .top)
                    .animation(.easeInOut(duration: 0.2))
            }
            .redacted(reason: redactionReason)
            .onFocusChange { isFocused = $0 }
        }
    }
}