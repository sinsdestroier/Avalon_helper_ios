import AVFoundation
import Foundation

enum SoundEffect {
    case setupOpen
    case clickPrimary
    case clickSecondary
    case assassinationSuspense
    case missionFailureMeme
    case missionSuccessMeme
    case missionSuccessNice
    case beastRoar
    case assassinationFailEpic
    case evilVictoryCarelessWhisper

    var resourceName: String {
        switch self {
        case .setupOpen:
            return "The_Dragon_s_Awakening"
        case .clickPrimary:
            return "click1"
        case .clickSecondary:
            return "click2"
        case .assassinationSuspense:
            return "OMG"
        case .missionFailureMeme:
            return "hey-hey-boy-meme"
        case .missionSuccessMeme:
            return "we did it.mp3"
        case .missionSuccessNice:
            return "click_nice"
        case .beastRoar:
            return "野獸叫"
        case .assassinationFailEpic:
            return "epic.swf"
        case .evilVictoryCarelessWhisper:
            return "careless_short"
        }
    }

    var fileExtension: String {
        switch self {
        case .clickPrimary:
            return "m4a"
        case .assassinationSuspense:
            return "mov"
        case .missionSuccessMeme:
            return "m4a"
        case .beastRoar, .evilVictoryCarelessWhisper:
            return "mov"
        default:
            return "mp3"
        }
    }

    var usesAVPlayer: Bool {
        switch self {
        case .assassinationSuspense, .beastRoar, .evilVictoryCarelessWhisper:
            return true
        default:
            return false
        }
    }

    var defaultVolume: Float {
        switch self {
        case .setupOpen:
            return 0.2
        case .missionSuccessMeme:
            return 0.45
        case .missionSuccessNice:
            return 0.85
        case .assassinationFailEpic:
            return 0.9
        case .evilVictoryCarelessWhisper:
            return 0.9
        default:
            return 1
        }
    }

    var supportsLooping: Bool {
        switch self {
        case .setupOpen:
            return true
        default:
            return false
        }
    }
}

@MainActor
final class SoundEffectPlayer {
    static let shared = SoundEffectPlayer()

    private var effectPlayers: [SoundEffect: AVAudioPlayer] = [:]
    private var streamingPlayers: [SoundEffect: AVPlayer] = [:]
    private var fadeTimers: [SoundEffect: Timer] = [:]
    private var activeLoopingEffect: SoundEffect?

    private init() { }

    func play(_ effect: SoundEffect, isEnabled: Bool, volume: Float? = nil, loop: Bool = false) {
        guard isEnabled else { return }
        cancelFade(for: effect)
        let targetVolume = volume ?? effect.defaultVolume

        if effect.usesAVPlayer {
            guard let player = streamingPlayer(for: effect) else { return }
            player.pause()
            player.seek(to: .zero)
            player.volume = targetVolume
            player.play()
            return
        }

        guard let player = audioPlayer(for: effect) else { return }
        player.numberOfLoops = loop && effect.supportsLooping ? -1 : 0
        player.volume = targetVolume
        player.currentTime = 0
        player.play()
    }

    func playLoopingIfNeeded(_ effect: SoundEffect, isEnabled: Bool, volume: Float? = nil) {
        guard isEnabled else {
            stop(effect)
            return
        }

        let targetVolume = volume ?? effect.defaultVolume
        guard let player = audioPlayer(for: effect) else { return }
        cancelFade(for: effect)

        if activeLoopingEffect == effect, player.isPlaying {
            player.setVolume(targetVolume, fadeDuration: 0.2)
            return
        }

        stopAllLoopingEffects()
        activeLoopingEffect = effect
        player.numberOfLoops = -1
        player.volume = targetVolume
        player.currentTime = 0
        player.play()
    }

    func stop(_ effect: SoundEffect) {
        cancelFade(for: effect)

        if let player = effectPlayers[effect] {
            player.stop()
            player.currentTime = 0
        }

        if let player = streamingPlayers[effect] {
            player.pause()
            player.seek(to: .zero)
            player.volume = effect.defaultVolume
        }

        if activeLoopingEffect == effect {
            activeLoopingEffect = nil
        }
    }

    func duration(for effect: SoundEffect) -> TimeInterval {
        if effect.usesAVPlayer {
            guard let url = resourceURL(for: effect) else { return 0 }
            let asset = AVURLAsset(url: url)
            let seconds = CMTimeGetSeconds(asset.duration)
            return seconds.isFinite ? seconds : 0
        }

        return audioPlayer(for: effect)?.duration ?? 0
    }

    func fadeOut(_ effect: SoundEffect, duration: TimeInterval) {
        guard duration > 0 else {
            stop(effect)
            return
        }

        cancelFade(for: effect)

        if effect.usesAVPlayer {
            guard let player = streamingPlayers[effect] else { return }
            let steps = 12
            let interval = duration / Double(steps)
            var remainingSteps = steps
            let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
                guard let self else {
                    timer.invalidate()
                    return
                }

                DispatchQueue.main.async {
                    remainingSteps -= 1
                    let progress = max(Double(remainingSteps), 0) / Double(steps)
                    player.volume = Float(progress)

                    if remainingSteps <= 0 {
                        timer.invalidate()
                        self.fadeTimers[effect] = nil
                        self.stop(effect)
                    }
                }
            }
            fadeTimers[effect] = timer
            return
        }

        guard let player = effectPlayers[effect] else { return }
        player.setVolume(0, fadeDuration: duration)
        let timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] timer in
            DispatchQueue.main.async {
                timer.invalidate()
                self?.fadeTimers[effect] = nil
                self?.stop(effect)
            }
        }
        fadeTimers[effect] = timer
    }

    func fadeOutLooping(_ effect: SoundEffect, duration: TimeInterval) {
        fadeOut(effect, duration: duration)
    }

    func stopAll() {
        for timer in fadeTimers.values {
            timer.invalidate()
        }
        fadeTimers.removeAll()

        for player in effectPlayers.values {
            player.stop()
            player.currentTime = 0
        }

        for player in streamingPlayers.values {
            player.pause()
            player.seek(to: .zero)
        }

        activeLoopingEffect = nil
    }

    func fadeTo(_ effect: SoundEffect, targetVolume: Float, duration: TimeInterval) {
        let clampedVolume = max(0, min(targetVolume, 1))
        guard duration > 0 else {
            setVolume(effect, volume: clampedVolume)
            return
        }

        cancelFade(for: effect)

        if effect.usesAVPlayer {
            guard let player = streamingPlayers[effect] else { return }
            let startVolume = player.volume
            let steps = 16
            let interval = duration / Double(steps)
            var currentStep = 0
            let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
                guard let self else {
                    timer.invalidate()
                    return
                }

                DispatchQueue.main.async {
                    currentStep += 1
                    let progress = min(Float(currentStep) / Float(steps), 1)
                    player.volume = startVolume + ((clampedVolume - startVolume) * progress)

                    if currentStep >= steps {
                        timer.invalidate()
                        self.fadeTimers[effect] = nil
                    }
                }
            }
            fadeTimers[effect] = timer
            return
        }

        guard let player = effectPlayers[effect] else { return }
        player.setVolume(clampedVolume, fadeDuration: duration)
    }

    private func audioPlayer(for effect: SoundEffect) -> AVAudioPlayer? {
        if let cachedPlayer = effectPlayers[effect] {
            return cachedPlayer
        }

        guard let url = resourceURL(for: effect) else { return nil }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            effectPlayers[effect] = player
            return player
        } catch {
            print("Failed to load sound \(effect.resourceName): \(error)")
            return nil
        }
    }

    private func streamingPlayer(for effect: SoundEffect) -> AVPlayer? {
        if let cachedPlayer = streamingPlayers[effect] {
            return cachedPlayer
        }

        guard let url = resourceURL(for: effect) else { return nil }

        let player = AVPlayer(url: url)
        player.volume = 1
        streamingPlayers[effect] = player
        return player
    }

    private func cancelFade(for effect: SoundEffect) {
        fadeTimers[effect]?.invalidate()
        fadeTimers[effect] = nil
    }

    private func resourceURL(for effect: SoundEffect) -> URL? {
        guard let url = Bundle.main.url(forResource: effect.resourceName, withExtension: effect.fileExtension) else {
            print("Missing sound file: \(effect.resourceName).\(effect.fileExtension)")
            return nil
        }
        return url
    }

    private func setVolume(_ effect: SoundEffect, volume: Float) {
        if let player = effectPlayers[effect] {
            player.volume = volume
        }

        if let player = streamingPlayers[effect] {
            player.volume = volume
        }
    }

    private func stopAllLoopingEffects() {
        if let activeLoopingEffect {
            stop(activeLoopingEffect)
        }
    }
}
