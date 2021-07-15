//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import Combine
import SRGDataProviderCombine

// MARK: View model

class ProgramGuideViewModel: ObservableObject {
    @Published var date: Date {
        didSet {
            updatePublishers()
        }
    }
    
    @Published private(set) var previousState: State = .loading
    @Published private(set) var state: State = .loading
    @Published private(set) var nextState: State = .loading
    
    init(date: Date = Date()) {
        self.date = date
        updatePublishers()
    }
    
    private func updatePublishers() {
        Self.tvPrograms(for: date)
            .receive(on: DispatchQueue.main)
            .assign(to: &$state)
        Self.tvPrograms(for: Self.day(before: date))
            .receive(on: DispatchQueue.main)
            .assign(to: &$previousState)
        Self.tvPrograms(for: Self.day(after: date))
            .receive(on: DispatchQueue.main)
            .assign(to: &$nextState)
    }
    
    private static func day(before date: Date) -> Date {
        return Calendar.current.date(byAdding: .day, value: -1, to: date) ?? Date()
    }
    
    private static func day(after date: Date) -> Date {
        return Calendar.current.date(byAdding: .day, value: 1, to: date) ?? Date()
    }
    
    private static func tvPrograms(for date: Date) -> AnyPublisher<State, Never> {
        return Publishers.PublishAndRepeat(onOutputFrom: Signal.wokenUp()) {
            return SRGDataProvider.current!.tvPrograms(for: ApplicationConfiguration.shared.vendor, day: SRGDay(from: date))
                .map { programCompositions in
                    return State.loaded(programCompositions)
                }
                .catch { error in
                    return Just(State.failed(error: error))
                }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: Types

extension ProgramGuideViewModel {
    enum State {
        case loading
        case failed(error: Error)
        case loaded([SRGProgramComposition])
    }
}
