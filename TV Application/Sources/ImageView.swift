//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import FetchImage
import SwiftUI

struct ImageView: View {
    let url: URL?
    let contentMode: ContentMode
    
    init(url: URL?, contentMode: ContentMode = .fit) {
        self.url = url
        self.contentMode = contentMode
    }
    
    var body: some View {
        if let url = url {
            FetchView(url: url, contentMode: contentMode)
        }
    }
}

extension ImageView {
    private struct FetchView: View {
        let contentMode: ContentMode
        
        @ObservedObject var fetchImage: FetchImage
        
        // Use separate state so that we can track image loading and only animate such changes. Since FetchImage
        // immediately fetches the image the state is initially set to true.
        @State var isLoading: Bool = true
        
        init(url: URL, contentMode: ContentMode) {
            fetchImage = FetchImage(url: url)
            self.contentMode = contentMode
        }
        
        public var body: some View {
            GeometryReader { geometry in
                fetchImage.view?
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .onReceive(fetchImage.$isLoading) { loading in
                        withAnimation {
                            isLoading = loading
                        }
                    }
                    .onAppear(perform: fetchImage.fetch)
                    .onDisappear(perform: fetchImage.cancel)
                    .opacity(isLoading ? 0 : 1)
            }
        }
    }
}
