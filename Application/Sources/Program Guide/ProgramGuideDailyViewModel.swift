//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import Combine

// MARK: View model

final class ProgramGuideDailyViewModel: ObservableObject {
    let day: SRGDay
    private let parentModel: ProgramGuideViewModel
    
    var channel: SRGChannel? {
        didSet {
            updatePublishers()
        }
    }
    
    @Published private(set) var state: State = .loading
    
    init(day: SRGDay, parentModel: ProgramGuideViewModel) {
        self.day = day
        self.parentModel = parentModel
        updatePublishers()
        parentModel.loadDay(day)
    }
    
    static func state(from state: ProgramGuideViewModel.State, for channel: SRGChannel?) -> ProgramGuideDailyViewModel.State {
        switch state {
        case .loading:
            return .loading
        case let .failed(error: error):
            return .failed(error: error)
        case let .loaded(programCompositions):
            return .loaded(programs(from: programCompositions, for: channel) ?? [])
        }
    }
    
    static func programs(from programCompositions: [SRGProgramComposition], for channel: SRGChannel?) -> [SRGProgram]? {
        if let channel = channel {
            return programCompositions.first(where: { $0.channel == channel })?.programs
        }
        else {
            return programCompositions.first?.programs
        }
    }
    
    private func updatePublishers() {
        parentModel.$states
            .compactMap { [weak self] states in
                guard let self = self, let state = states[self.day] else { return nil }
                return Self.state(from: state, for: self.channel)
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$state)
    }
}

// MARK: Types

extension ProgramGuideDailyViewModel {
    enum State {
        case loading
        case failed(error: Error)
        case loaded([SRGProgram])
    }
}
