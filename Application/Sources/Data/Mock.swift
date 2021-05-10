//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import SwiftUI

struct Mock {
    enum Media: String {
        case standard
        case minimal
        case rich
        case overflow
        case blocked
        case livestream
        case fourThree
        case fourFive
        case nineSixteen
        case square
    }
    
    static func media(_ kind: Media? = .standard) -> SRGMedia? {
        return mockObject(kind?.rawValue, type: SRGMedia.self)
    }
    
    enum Show: String {
        case standard
        case overflow
    }
    
    static func show(_ kind: Show? = .standard) -> SRGShow? {
        return mockObject(kind?.rawValue, type: SRGShow.self)
    }
    
    enum Topic: String {
        case standard
        case overflow
    }
    
    static func topic(_ kind: Topic? = .standard) -> SRGTopic? {
        return mockObject(kind?.rawValue, type: SRGTopic.self)
    }
    
    private static func mockObject<T>(_ name: String?, type: T.Type) -> T? {
        guard let name = name, let clazz = type as? AnyClass else { return nil }
        let asset = NSDataAsset(name: "\(NSStringFromClass(clazz))_\(name)")!
        let jsonData = try! JSONSerialization.jsonObject(with: asset.data, options: []) as? [String: Any]
        return try! MTLJSONAdapter(modelClass: clazz)?.model(fromJSONDictionary: jsonData) as! T
    }
}
