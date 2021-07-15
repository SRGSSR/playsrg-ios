//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import Combine
import UIKit

// MARK: View controller

final class ProgramGuideDailyViewController: UIViewController {
    let day: SRGDay
    private let model: ProgramGuideDailyViewModel
    
    var channel: SRGChannel? {
        didSet {
            model.channel = channel
        }
    }
    
    var programs: [SRGProgram] = []
    
    // TODO: Just for quick data display
    private weak var tableView: UITableView!
    
    private var cancellables = Set<AnyCancellable>()
    
    init(day: SRGDay, parentModel: ProgramGuideViewModel) {
        self.model = ProgramGuideDailyViewModel(day: day, parentModel: parentModel)
        self.day = day
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        let view = UIView(frame: UIScreen.main.bounds)
        
        let tableView = UITableView()
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(tableView)
        self.tableView = tableView
        
        self.view = view
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "programCell")
        
        model.$state
            .sink { [weak self] state in
                self?.reloadData(for: state)
            }
            .store(in: &cancellables)
    }
    
    func reloadData(for state: ProgramGuideDailyViewModel.State) {
        switch state {
        case let .loaded(programs):
            self.programs = programs
        default:
            self.programs = []
        }
        tableView.reloadData()
    }
}

extension ProgramGuideDailyViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return programs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: "programCell", for: indexPath)
    }
}

extension ProgramGuideDailyViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let program = programs[indexPath.row]
        cell.textLabel?.text = program.title
    }
}
