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

// TODO: Should completion blocks be called on the next run loop with a dispatch_async?

extension UITableView {
    @objc public func reloadDataAnimated(oldObjects: [NSObject], newObjects: [NSObject], updateData: () -> Void, completion: ((Bool) -> Void)?) {
        if self.numberOfSections <= 1 && !oldObjects.isEmpty && !newObjects.isEmpty && oldObjects != newObjects {
            let changes = diff(old: oldObjects, new: newObjects)
            self.reload(changes: changes, section: 0, insertionAnimation: .automatic, deletionAnimation: .automatic, replacementAnimation: .automatic, updateData: updateData, completion: completion)
        }
        else {
            updateData()
            self.reloadData()
            completion?(true)
        }
    }
}

extension UICollectionView {
    @objc public func reloadDataAnimated(oldObjects: [NSObject], newObjects: [NSObject], updateData: () -> Void, completion: ((Bool) -> Void)?) {
        if self.numberOfSections <= 1 && !oldObjects.isEmpty && !newObjects.isEmpty {
            let changes = diff(old: oldObjects, new: newObjects)
            self.reload(changes: changes, section: 0, updateData: updateData, completion: completion)
        }
        else {
            updateData()
            self.reloadData()
            completion?(true)
        }
    }
}
