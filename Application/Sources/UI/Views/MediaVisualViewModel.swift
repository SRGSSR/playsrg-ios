//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

import Combine

// MARK: View model

final class MediaVisualViewModel: ObservableObject {
    @Published var media: SRGMedia? {
        didSet {
            updatePublishers()
        }
    }
    
    @Published private(set) var progress: Double = 0
    
    private var taskHandle: String?
    private var cancellables = Set<AnyCancellable>()
    
    deinit {
        HistoryPlaybackProgressAsyncCancel(taskHandle)
    }
    
    func imageUrl(for scale: ImageScale) -> URL? {
        return media?.imageUrl(for: scale)
    }
    
    var availabilityBadgeProperties: (text: String, color: UIColor)? {
        guard let media = media else { return nil }
        return MediaDescription.availabilityBadgeProperties(for: media)
    }
    
    var is360: Bool {
        return media?.presentation == .presentation360
    }
    
    var isMultiAudioAvailable: Bool {
        guard let media = media else { return false }
        return media.play_isMultiAudioAvailable
    }
    
    var isAudioDescriptionAvailable: Bool {
        guard let media = media else { return false }
        return media.play_isAudioDescriptionAvailable
    }
    
    var areSubtitlesAvailable: Bool {
        guard let media = media else { return false }
        return media.play_areSubtitlesAvailable
    }
    
    var youthProtectionColor: SRGYouthProtectionColor? {
        return media?.youthProtectionColor
    }
    
    var duration: Double? {
        guard let media = media else { return nil }
        return MediaDescription.duration(for: media)
    }
    
    private func updatePublishers() {
        cancellables = []
        
        if let media = media {
            Signal.historyUpdate(for: media.urn)
                .sink { [weak self] _ in
                    self?.updateProgress()
                }
                .store(in: &cancellables)
        }
        
        updateProgress()
    }
    
    // Cannot be wrapped into Futures because the progress update block might be called several times
    private func updateProgress() {
        HistoryPlaybackProgressAsyncCancel(taskHandle)
        taskHandle = HistoryPlaybackProgressForMediaMetadataAsync(media) { progress in
            DispatchQueue.main.async {
                self.progress = Double(progress)
            }
        }
    }
}
