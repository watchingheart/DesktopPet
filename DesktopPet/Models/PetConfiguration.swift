import Foundation
import CoreGraphics

struct PetConfiguration: Codable {
    var petName: String = "小宠物"
    var petSize: CGFloat = 150
    var behaviorWeights: BehaviorWeightsConfig = BehaviorWeightsConfig()
    var behaviorIntervals: BehaviorIntervalsConfig = BehaviorIntervalsConfig()
    var interactionSettings: InteractionSettingsConfig = InteractionSettingsConfig()
    var appearanceSettings: AppearanceSettingsConfig = AppearanceSettingsConfig()

    static var `default`: PetConfiguration {
        PetConfiguration()
    }
}

struct BehaviorWeightsConfig: Codable {
    var idle: Double = 0.4
    var walk: Double = 0.3
    var sit: Double = 0.2
    var sleep: Double = 0.1
}

struct BehaviorIntervalsConfig: Codable {
    var minInterval: Double = 3.0
    var maxInterval: Double = 10.0
}

struct InteractionSettingsConfig: Codable {
    var enableClickReaction: Bool = true
    var enableDoubleClick: Bool = true
    var enableDrag: Bool = true
    var enableMouseFollow: Bool = true
}

struct AppearanceSettingsConfig: Codable {
    var opacity: Double = 1.0
    var scale: Double = 1.0
    var alwaysOnTop: Bool = true
    var showShadow: Bool = false
}

// 配置管理器
class ConfigurationManager {
    static let shared = ConfigurationManager()

    private let defaults = UserDefaults.standard
    private let configKey = "petConfiguration"

    var configuration: PetConfiguration {
        get {
            guard let data = defaults.data(forKey: configKey),
                  let config = try? JSONDecoder().decode(PetConfiguration.self, from: data) else {
                return .default
            }
            return config
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: configKey)
        }
    }

    func reset() {
        configuration = .default
    }
}
