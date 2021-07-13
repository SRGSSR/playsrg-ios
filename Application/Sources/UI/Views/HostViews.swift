//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import SwiftUI
import UIKit

/**
 *  Collection view cell hosting `SwiftUI` content.
 */
class HostCollectionViewCell<Content: View>: UICollectionViewCell {
    private var hostController: UIHostingController<Content>?
    
    private func update(with content: Content?) {
        if let rootView = content {
            if let hostController = hostController {
                hostController.rootView = rootView
            }
            else {
                hostController = UIHostingController(rootView: rootView, ignoreSafeArea: true)
            }
            
            if let hostView = hostController?.view, hostView.superview != contentView {
                hostView.frame = contentView.bounds
                hostView.backgroundColor = .clear
                hostView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                contentView.addSubview(hostView)
            }
        }
        else if let hostView = hostController?.view {
            hostView.removeFromSuperview()
        }
    }
    
    var content: Content? {
        didSet {
            update(with: content)
        }
    }
    
    override var isSelected: Bool {
        didSet {
            alpha = isSelected ? 0.3 : 1
        }
    }
}

/**
 *  Collection view reusable view hosting `SwiftUI` content.
 */
class HostSupplementaryView<Content: View>: UICollectionReusableView {
    private var hostController: UIHostingController<Content>?
    
    private func update(with content: Content?) {
        if let rootView = content {
            if let hostController = hostController {
                hostController.rootView = rootView
            }
            else {
                hostController = UIHostingController(rootView: rootView, ignoreSafeArea: true)
            }
            
            if let hostView = hostController?.view, hostView.superview != self {
                hostView.frame = bounds
                hostView.backgroundColor = .clear
                hostView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                addSubview(hostView)
            }
        }
        else if let hostView = hostController?.view {
            hostView.removeFromSuperview()
        }
    }
    
    var content: Content? {
        didSet {
            update(with: content)
        }
    }
}

/**
 *  Table view cell hosting `SwiftUI` content.
 */
class HostTableViewCell<Content: View>: UITableViewCell {
    private var hostController: UIHostingController<Content>?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.tintColor = .red
        self.backgroundColor = .clear
        
        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = .clear
        self.selectedBackgroundView = selectedBackgroundView
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func update(with content: Content?) {
        if let rootView = content {
            if let hostController = hostController {
                hostController.rootView = rootView
            }
            else {
                hostController = UIHostingController(rootView: rootView, ignoreSafeArea: true)
            }
            
            if let hostView = hostController?.view, hostView.superview != contentView {
                hostView.frame = contentView.bounds
                hostView.backgroundColor = .clear
                hostView.translatesAutoresizingMaskIntoConstraints = false
                contentView.addSubview(hostView)
                
                NSLayoutConstraint.activate([
                    hostView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: LayoutMargin / 2),
                    hostView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -LayoutMargin / 2),
                    hostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: LayoutMargin),
                    hostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -LayoutMargin)
                ])
            }
        }
        else if let hostView = hostController?.view {
            hostView.removeFromSuperview()
        }
    }
    
    var content: Content? {
        didSet {
            update(with: content)
        }
    }
}

/**
 *  Simple view hosting `SwiftUI` content.
 */
class HostView<Content: View>: UIView {
    let ignoresSafeArea: Bool
    
    private var hostController: UIHostingController<Content>?
    
    init(frame: CGRect, ignoresSafeArea: Bool) {
        self.ignoresSafeArea = ignoresSafeArea
        super.init(frame: frame)
    }
    
    override convenience init(frame: CGRect) {
        self.init(frame: frame, ignoresSafeArea: true)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func update(with content: Content?) {
        if let rootView = content {
            if let hostController = hostController {
                hostController.rootView = rootView
            }
            else {
                hostController = UIHostingController(rootView: rootView, ignoreSafeArea: ignoresSafeArea)
            }
            
            if let hostView = hostController?.view, hostView.superview != self {
                hostView.frame = bounds
                hostView.backgroundColor = .clear
                hostView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                addSubview(hostView)
            }
        }
        else if let hostView = hostController?.view {
            hostView.removeFromSuperview()
        }
    }
    
    var content: Content? {
        didSet {
            update(with: content)
        }
    }
}
