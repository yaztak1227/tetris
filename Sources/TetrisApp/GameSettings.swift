import Foundation
import TetrisCore

enum GameInputAction: String, CaseIterable, Codable, Identifiable {
    case moveLeft
    case moveRight
    case softDrop
    case hardDrop
    case rotateClockwise
    case rotateCounterClockwise
    case hold
    case restart
    case start
    case pause

    var id: String { rawValue }

    var title: String {
        switch self {
        case .moveLeft:
            return "Move Left"
        case .moveRight:
            return "Move Right"
        case .softDrop:
            return "Soft Drop"
        case .hardDrop:
            return "Hard Drop"
        case .rotateClockwise:
            return "Rotate CW"
        case .rotateCounterClockwise:
            return "Rotate CCW"
        case .hold:
            return "Hold"
        case .restart:
            return "Restart"
        case .start:
            return "Start"
        case .pause:
            return "Pause"
        }
    }

    func title(localizer: AppLocalizer) -> String {
        localizer.text("settings/inputActions/\(rawValue)")
    }
}

struct GameSettings: Codable, Equatable, Sendable {
    var holdMoveMultiplier: Double = 1.5
    var gravityMultiplier: Double = 1.0
    var horizontalAutoShiftDelayMilliseconds: Double = 80
    var horizontalAutoRepeatIntervalMilliseconds: Double = 35
    var keyBindings: [GameInputAction: Set<String>] = GameSettings.defaultBindings

    static let defaultBindings: [GameInputAction: Set<String>] = [
        .moveLeft: ["left"],
        .moveRight: ["right"],
        .softDrop: ["down"],
        .hardDrop: ["space"],
        .rotateClockwise: ["up", "x"],
        .rotateCounterClockwise: ["z"],
        .hold: ["c", "shift"],
        .restart: ["r"],
        .start: ["return"],
        .pause: ["escape"]
    ]

    func action(for key: String) -> GameInputAction? {
        keyBindings.first { _, keys in keys.contains(key) }?.key
    }

    mutating func bind(_ key: String, to action: GameInputAction) {
        for existingAction in GameInputAction.allCases {
            keyBindings[existingAction]?.remove(key)
        }
        keyBindings[action] = [key]
    }

    func displayBinding(for action: GameInputAction) -> String {
        let keys = keyBindings[action, default: []].sorted()
        return keys.map(Self.displayName(for:)).joined(separator: " / ")
    }

    func displayBinding(for action: GameInputAction, localizer: AppLocalizer) -> String {
        let keys = keyBindings[action, default: []].sorted()
        return keys.map { Self.displayName(for: $0, localizer: localizer) }.joined(separator: " / ")
    }

    static func displayName(for key: String) -> String {
        switch key {
        case "left":
            return "Left"
        case "right":
            return "Right"
        case "down":
            return "Down"
        case "up":
            return "Up"
        case "space":
            return "Space"
        case "shift":
            return "Shift"
        case "return":
            return "Return"
        case "escape":
            return "Esc"
        default:
            return key.uppercased()
        }
    }

    static func displayName(for key: String, localizer: AppLocalizer) -> String {
        let localized = localizer.text("settings/keyNames/\(key)")
        return localized == "settings/keyNames/\(key)" ? displayName(for: key) : localized
    }
}

enum KeyInputPhase: Equatable, Sendable {
    case down
    case up
}

struct KeyInput: Equatable, Sendable {
    let key: String
    let isRepeat: Bool
    let phase: KeyInputPhase

    init(key: String, isRepeat: Bool, phase: KeyInputPhase = .down) {
        self.key = key
        self.isRepeat = isRepeat
        self.phase = phase
    }
}

struct ClearEffectToast: Equatable, Identifiable, Sendable {
    enum Kind: Equatable, Sendable {
        case normal
        case tetris
        case tSpin
    }

    let id: Int
    let title: String
    let subtitle: String
    let kind: Kind
}

protocol GameSettingsPersisting: AnyObject {
    func load() -> GameSettings?
    func save(_ settings: GameSettings)
}

final class UserDefaultsGameSettingsStore: GameSettingsPersisting {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "game.settings") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> GameSettings? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(GameSettings.self, from: data)
    }

    func save(_ settings: GameSettings) {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }
        defaults.set(data, forKey: key)
    }
}
