//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import Combine
import UIKit

// MARK: View controller

final class ProgramGuideViewController: UIViewController {
    let model: ProgramGuideViewModel
    
    private var cancellables = Set<AnyCancellable>()
    
    init(date: Date = Date()) {
        model = ProgramGuideViewModel(date: date)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .srgGray16
        self.view = view
     }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        model.$state
            .sink { state in
                print("State: \(state)")
            }
            .store(in: &cancellables)
        model.$previousState
            .sink { state in
                print("Previous state: \(state)")
            }
            .store(in: &cancellables)
        model.$nextState
            .sink { state in
                print("Next state: \(state)")
            }
            .store(in: &cancellables)
    }
}
