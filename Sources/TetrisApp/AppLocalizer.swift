import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case japanese = "ja"

    var id: String { rawValue }

    static var preferred: AppLanguage {
        Locale.current.language.languageCode?.identifier == AppLanguage.japanese.rawValue ? .japanese : .english
    }

    static func resolved(storedCode: String?, preferred: AppLanguage = AppLanguage.preferred) -> AppLanguage {
        storedCode.flatMap(AppLanguage.init(rawValue:)) ?? preferred
    }
}

struct AppLocalizer: Equatable, Sendable {
    enum LoadError: Error, Equatable {
        case missingResource(String)
    }

    let language: AppLanguage
    private let strings: [String: String]
    private let fallbackStrings: [String: String]

    init(
        language: AppLanguage,
        strings: [String: String],
        fallbackStrings: [String: String] = [:]
    ) {
        self.language = language
        self.strings = strings
        self.fallbackStrings = fallbackStrings
    }

    static func load(language: AppLanguage, bundle: Bundle = .module) throws -> Self {
        let fallback = try loadStrings(language: .english, bundle: bundle)
        let strings = language == .english ? fallback : try loadStrings(language: language, bundle: bundle)
        return AppLocalizer(language: language, strings: strings, fallbackStrings: fallback)
    }

    static func loadOrFallback(language: AppLanguage, bundle: Bundle = .module) -> Self {
        if let localizer = try? load(language: language, bundle: bundle) {
            return localizer
        }

        return (try? load(language: .english, bundle: bundle)) ?? AppLocalizer(language: .english, strings: [:])
    }

    func text(_ key: String) -> String {
        strings[key] ?? fallbackStrings[key] ?? key
    }

    func languageName(_ language: AppLanguage) -> String {
        text("settings/language/options/\(language.rawValue)")
    }

    private static func loadStrings(language: AppLanguage, bundle: Bundle) throws -> [String: String] {
        for url in candidateURLs(for: language, bundle: bundle) {
            guard FileManager.default.fileExists(atPath: url.path) else {
                continue
            }

            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([String: String].self, from: data)
        }

        if let builtIn = builtInStrings(for: language) {
            return builtIn
        }

        throw LoadError.missingResource(language.rawValue)
    }

    private static func candidateURLs(for language: AppLanguage, bundle: Bundle) -> [URL] {
        let resourceName = language.rawValue
        let executableBundleURL = Bundle.main.executableURL?
            .deletingLastPathComponent()
            .appendingPathComponent("Tetris_TetrisApp.bundle", isDirectory: true)

        return [
            bundle.url(forResource: resourceName, withExtension: "json", subdirectory: "Localizations"),
            bundle.url(forResource: resourceName, withExtension: "json"),
            Bundle.main.url(forResource: resourceName, withExtension: "json", subdirectory: "Localizations"),
            Bundle.main.url(forResource: resourceName, withExtension: "json"),
            executableBundleURL?.appendingPathComponent("\(resourceName).json"),
            sourceResourceURL(for: language)
        ].compactMap(\.self)
    }

    private static func sourceResourceURL(for language: AppLanguage) -> URL? {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/Localizations/\(language.rawValue).json")
    }

    private static func builtInStrings(for language: AppLanguage) -> [String: String]? {
        switch language {
        case .english:
            return [
                "app/title": "TETRIS",
                "common/status/home": "HOME",
                "common/status/pause": "PAUSE",
                "common/status/settings": "SETTINGS",
                "common/status/ready": "READY",
                "common/status/play": "PLAY",
                "common/status/standby": "STANDBY",
                "common/status/gameOver": "GAME OVER",
                "common/status/complete": "COMPLETE",
                "common/keyCapture/press": "Press...",
                "home/mode/marathon": "MARATHON",
                "home/buttons/start": "Start",
                "home/buttons/settings": "Settings",
                "home/meters/time": "TIME",
                "home/meters/status": "STATUS",
                "home/meters/start": "START",
                "home/message/noPiecesUntilStart": "No pieces are generated until Start.",
                "game/labels/next": "NEXT",
                "game/labels/player": "PLAYER",
                "game/labels/myInfo": "MY INFO",
                "game/labels/hold": "HOLD",
                "game/labels/score": "SCORE",
                "game/stats/level": "LEVEL",
                "game/stats/lines": "LINES",
                "game/stats/ren": "REN",
                "game/stats/b2b": "B2B",
                "game/stats/on": "ON",
                "game/buttons/pause": "Pause",
                "game/buttons/restart": "Restart",
                "game/events/ready": "READY",
                "game/events/go": "GO",
                "game/events/paused": "PAUSED",
                "game/events/resume": "RESUME",
                "game/events/lock": "LOCK",
                "game/events/lockError": "LOCK ERROR",
                "game/events/gameError": "GAME ERROR",
                "pause/title": "PAUSED",
                "pause/buttons/resume": "Resume",
                "pause/buttons/restart": "Restart",
                "pause/buttons/settings": "Settings",
                "settings/title": "Settings",
                "settings/buttons/back": "Back",
                "settings/meters/return": "RETURN",
                "settings/sections/tuning": "TUNING",
                "settings/sections/keyConfig": "KEY CONFIG",
                "settings/sections/language": "LANGUAGE",
                "settings/tuning/moveHold": "MOVE HOLD",
                "settings/tuning/horizontalDelay": "DAS DELAY",
                "settings/tuning/horizontalInterval": "MOVE INTERVAL",
                "settings/tuning/gravity": "GRAVITY",
                "settings/help/changesApplyImmediately": "Changes apply to the next input immediately.",
                "settings/language/current": "LANGUAGE",
                "settings/language/options/en": "English",
                "settings/language/options/ja": "Japanese",
                "settings/inputActions/moveLeft": "Move Left",
                "settings/inputActions/moveRight": "Move Right",
                "settings/inputActions/softDrop": "Soft Drop",
                "settings/inputActions/hardDrop": "Hard Drop",
                "settings/inputActions/rotateClockwise": "Rotate CW",
                "settings/inputActions/rotateCounterClockwise": "Rotate CCW",
                "settings/inputActions/hold": "Hold",
                "settings/inputActions/restart": "Restart",
                "settings/inputActions/start": "Start",
                "settings/inputActions/pause": "Pause",
                "settings/keyNames/left": "Left",
                "settings/keyNames/right": "Right",
                "settings/keyNames/down": "Down",
                "settings/keyNames/up": "Up",
                "settings/keyNames/space": "Space",
                "settings/keyNames/shift": "Shift",
                "settings/keyNames/return": "Return",
                "settings/keyNames/escape": "Esc"
            ]
        case .japanese:
            return [
                "app/title": "テトリス",
                "common/status/home": "ホーム",
                "common/status/pause": "ポーズ",
                "common/status/settings": "設定",
                "common/status/ready": "準備",
                "common/status/play": "プレイ",
                "common/status/standby": "待機",
                "common/status/gameOver": "ゲームオーバー",
                "common/status/complete": "完了",
                "common/keyCapture/press": "入力...",
                "home/mode/marathon": "マラソン",
                "home/buttons/start": "開始",
                "home/buttons/settings": "設定",
                "home/meters/time": "時間",
                "home/meters/status": "状態",
                "home/meters/start": "開始",
                "home/message/noPiecesUntilStart": "開始するまでミノとNEXTは生成されません。",
                "game/labels/next": "NEXT",
                "game/labels/player": "プレイヤー",
                "game/labels/myInfo": "情報",
                "game/labels/hold": "ホールド",
                "game/labels/score": "スコア",
                "game/stats/level": "レベル",
                "game/stats/lines": "ライン",
                "game/stats/ren": "REN",
                "game/stats/b2b": "B2B",
                "game/stats/on": "ON",
                "game/buttons/pause": "ポーズ",
                "game/buttons/restart": "リスタート",
                "game/events/ready": "準備OK",
                "game/events/go": "開始!",
                "game/events/paused": "ポーズ",
                "game/events/resume": "再開",
                "game/events/lock": "固定",
                "game/events/lockError": "固定エラー",
                "game/events/gameError": "ゲームエラー",
                "pause/title": "ポーズ",
                "pause/buttons/resume": "再開",
                "pause/buttons/restart": "リスタート",
                "pause/buttons/settings": "設定",
                "settings/title": "設定",
                "settings/buttons/back": "戻る",
                "settings/meters/return": "戻り先",
                "settings/sections/tuning": "調整",
                "settings/sections/keyConfig": "キー設定",
                "settings/sections/language": "言語",
                "settings/tuning/moveHold": "長押し移動",
                "settings/tuning/horizontalDelay": "長押し判定",
                "settings/tuning/horizontalInterval": "横移動間隔",
                "settings/tuning/gravity": "下降速度",
                "settings/help/changesApplyImmediately": "変更は次の入力からすぐ反映されます。",
                "settings/language/current": "言語",
                "settings/language/options/en": "English",
                "settings/language/options/ja": "日本語",
                "settings/inputActions/moveLeft": "左移動",
                "settings/inputActions/moveRight": "右移動",
                "settings/inputActions/softDrop": "ソフトドロップ",
                "settings/inputActions/hardDrop": "ハードドロップ",
                "settings/inputActions/rotateClockwise": "右回転",
                "settings/inputActions/rotateCounterClockwise": "左回転",
                "settings/inputActions/hold": "ホールド",
                "settings/inputActions/restart": "リスタート",
                "settings/inputActions/start": "開始",
                "settings/inputActions/pause": "ポーズ",
                "settings/keyNames/left": "左",
                "settings/keyNames/right": "右",
                "settings/keyNames/down": "下",
                "settings/keyNames/up": "上",
                "settings/keyNames/space": "スペース",
                "settings/keyNames/shift": "シフト",
                "settings/keyNames/return": "リターン",
                "settings/keyNames/escape": "Esc"
            ]
        }
    }
}
