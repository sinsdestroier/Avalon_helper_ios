import Foundation
import Observation

@Observable
final class AppSettings {
    var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: "AppSettings.soundEnabled")
        }
    }

    var effectsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(effectsEnabled, forKey: "AppSettings.effectsEnabled")
        }
    }

    init() {
        soundEnabled = true
        effectsEnabled = true
    }
}
