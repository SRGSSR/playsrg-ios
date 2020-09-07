//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import SRGAppearance
import SwiftUI

struct MediaCell: View {
    private struct DescriptionView: View {
        let media: SRGMedia?
        
        var body: some View {
            Text(MediaDescription.title(for: media))
                .srgFont(.regular, size: .subtitle)
                .lineLimit(2)
            Text(MediaDescription.subtitle(for: media))
                .srgFont(.regular, size: .caption)
                .lineLimit(1)
        }
    }
    
    let media: SRGMedia?
    
    private var redactionReason: RedactionReasons {
        return media == nil ? .placeholder : .init()
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                MediaVisual(media: media, scale: .small, contentMode: .fit) {
                    Rectangle()
                        .fill(Color.clear)
                }
                .frame(width: geometry.size.width, height: geometry.size.width * 9 / 16)
                
                DescriptionView(media: media)
                    .frame(width: geometry.size.width, alignment: .leading)
            }
            .redacted(reason: redactionReason)
        }
    }
}
