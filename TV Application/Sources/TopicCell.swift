//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import SRGDataProviderModel
import SwiftUI

struct TopicCell: View {
    static let cellSize = CGSize(width: 249, height: 140)
    
    let topic: SRGTopic?
    
    private var title: String {
        guard let topic = topic else { return String(repeating: " ", count: .random(in: 5..<10)) }
        return topic.title
    }
    
    private var imageUrl: URL? {
        return topic?.imageURL(for: .height, withValue: Self.cellSize.height, type: .default)
    }
    
    private var redactionReason: RedactionReasons {
        return topic == nil ? .placeholder : .init()
    }
    
    var body: some View {
        Button(action: { /* Open the topic detail page */ }) {
            ZStack {
                ImageView(url: imageUrl)
                    .whenRedacted { $0.hidden() }
                Text(title)
                    .lineLimit(1)
                    .padding()
                    .frame(width: Self.cellSize.width, height: Self.cellSize.height)
                    .background(Color(white: 0, opacity: 0.4))
            }
        }
        .buttonStyle(CardButtonStyle())
        .padding(.top, 20)
        .padding(.bottom, 80)
        .redacted(reason: redactionReason)
    }
}
