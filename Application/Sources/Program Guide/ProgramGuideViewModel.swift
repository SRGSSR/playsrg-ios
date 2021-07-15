//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import Combine
import SRGDataProviderCombine

// MARK: View model

final class ProgramGuideViewModel: ObservableObject {
    @Published private(set) var states: [SRGDay: State] = [:]
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadDay(.today)
    }
    
    // TODO: We probably don't want to reload all cached days when the application is woken up, but
    //       to trigger refreshes again when navigating days
    func loadDay(_ day: SRGDay) {
        guard states[day] == nil else { return }
        Self.tvPrograms(for: day)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.states[day] = state
            }
            .store(in: &cancellables)
    }
    
    private static func tvPrograms(for day: SRGDay) -> AnyPublisher<State, Never> {
        return SRGDataProvider.current!.tvPrograms(for: ApplicationConfiguration.shared.vendor, day: day)
            .map { programCompositions in
                return State.loaded(programCompositions)
            }
            .catch { error in
                return Just(State.failed(error: error))
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
