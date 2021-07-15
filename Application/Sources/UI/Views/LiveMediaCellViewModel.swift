//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

// MARK: View model

final class LiveMediaCellViewModel: ObservableObject {
    @Published var media: SRGMedia? {
        didSet {
            registerForChannelUpdates(for: media)
        }
    }
    
    @Published private(set) var programComposition: SRGProgramComposition?
    @Published private(set) var date = Date()
    
    private var channelObserver: Any?
    
    init() {
        Timer.publish(every: 10, on: .main, in: .common)
            .autoconnect()
            .assign(to: &$date)
    }
    
    deinit {
        unregisterChannelUpdates()
    }
    
    private func registerForChannelUpdates(for media: SRGMedia?) {
        unregisterChannelUpdates()
        
        if let media = media, let channel = media.channel, media.contentType == .livestream {
            channelObserver = ChannelService.shared.addObserverForUpdates(with: channel, livestreamUid: media.uid) { [weak self] composition in
                guard let self = self else { return }
                self.programComposition = composition
            }
        }
    }
    
    private func unregisterChannelUpdates() {
        programComposition = nil
        ChannelService.shared.removeObserver(channelObserver)
    }
}

extension LiveMediaCellViewModel {
    var channel: SRGChannel? {
        return programComposition?.channel ?? media?.channel
    }
    
    var logoImage: UIImage? {
        return channel?.play_largeLogoImage
    }
    
    var program: SRGProgram? {
        return programComposition?.play_program(at: date)
    }
    
    var title: String? {
        if let channel = channel {
            return program?.title ?? channel.title
        }
        else if let media = media {
            return MediaDescription.title(for: media)
        }
        else {
            return nil
        }
    }
    
    var subtitle: String? {
        if let media = media, media.contentType == .scheduledLivestream {
            return MediaDescription.subtitle(for: media)
        }
        else {
            guard let program = program else { return nil }
            let remainingTimeInterval = program.endDate.timeIntervalSince(date)
            let remainingTime = PlayRemainingTimeFormattedDuration(remainingTimeInterval)
            return String(format: NSLocalizedString("%@ remaining", comment: "Text displayed on live cells telling how much time remains for a program currently on air"), remainingTime)
        }
    }
    
    var accessibilityLabel: String? {
        if let channel = channel {
            var label = String(format: PlaySRGAccessibilityLocalizedString("%@ live", comment: "Live content label, with a channel title"), channel.title)
            if let program = program {
                label.append(", \(program.title)")
            }
            return label
        }
        else if let media = media {
            return MediaDescription.accessibilityLabel(for: media)
        }
        else {
            return nil
        }
    }
    
    var progress: Double? {
        if channel != nil {
            guard let program = program else { return 0 }
            return date.timeIntervalSince(program.startDate) / program.endDate.timeIntervalSince(program.startDate)
        }
        else if let media = media, media.contentType == .scheduledLivestream, media.timeAvailability(at: Date()) == .available,
                let startDate = media.startDate,
                let endDate = media.endDate {
            let progress = Date().timeIntervalSince(startDate) / endDate.timeIntervalSince(startDate)
            return progress.clamped(to: 0...1)
        }
        else {
            return nil
        }
    }
    
    var imageUrl: URL? {
        if let channel = channel {
            return program?.imageUrl(for: .small) ?? channel.imageUrl(for: .small)
        }
        else {
            return media?.imageUrl(for: .small)
        }
    }
}
