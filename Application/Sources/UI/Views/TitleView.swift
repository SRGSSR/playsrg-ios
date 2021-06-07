//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import SwiftUI

/// Behavior: h-exp, v-exp
struct TitleView: View {
    let text: String?
    
    var body: some View {
        if let text = text {
            Text(text)
                .srgFont(.H1)
                .foregroundColor(.srgGray5)
                .lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

class TitleViewSize: NSObject {
    @objc static func recommended(text: String?) -> NSCollectionLayoutSize {
        if let text = text, !text.isEmpty {
            return NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(constant(iOS: 60, tvOS: 100)))
        }
        else {
            return NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(LayoutHeaderHeightZero))
        }
    }
}

struct TitleView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TitleView(text: "Title")
            TitleView(text: .loremIpsum)
            TitleView(text: nil)
        }
        .previewLayout(.fixed(width: 800, height: 200))
    }
}
