//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import DeepDiff
import UIKit

extension NSObject: DiffAware {
    public var diffId: Int {
        return self.hashValue
    }
    
    public static func compareContent(_ a: NSObject, _ b: NSObject) -> Bool {
        return a == b
    }
}

extension UITableView {
    @objc public func reloadDataAnimated(oldObjects: [NSObject], newObjects: [NSObject], section: Int = 0, updateData: () -> Void) {
        if !oldObjects.isEmpty && !newObjects.isEmpty {
            let changes = diff(old: oldObjects, new: newObjects)
            self.reload(changes: changes, section: section, insertionAnimation: .automatic, deletionAnimation: .automatic, replacementAnimation: .automatic, updateData: updateData, completion: nil)
        }
        else {
            updateData()
            self.reloadData()
        }
    }
}

extension UICollectionView {
    @objc public func reloadDataAnimated(oldObjects: [NSObject], newObjects: [NSObject], updateData: () -> Void) {
        if !oldObjects.isEmpty && !newObjects.isEmpty {
            let changes = diff(old: oldObjects, new: newObjects)
            self.reload(changes: changes, updateData: updateData)
        }
        else {
            updateData()
            self.reloadData()
        }
    }
}
