import AVFoundation
import Foundation
import Observation
import TetrisCore

enum GameSound: Equatable, Sendable {
    case hardDrop
    case lineClear
    case levelUp
    case single
    case double
    case triple
    case tetris
    case tSpin
    case tSpinSingle
    case tSpinDouble
    case tSpinTriple
    case backToBack
    case ren
    case gameOver

    var resourceFileName: String? {
        switch self {
        case .single:
            return "single"
        case .double:
            return "double"
        case .triple:
            return "triple"
        case .tetris:
            return "tetris"
        case .tSpin:
            return "t_spin"
        case .tSpinSingle:
            return "t_spin_single"
        case .tSpinDouble:
            return "t_spin_double"
        case .tSpinTriple:
            return "t_spin_triple"
        case .backToBack:
            return "back_to_back"
        case .ren:
            return "ren"
        case .gameOver:
            return "game_over"
        case .hardDrop,
             .lineClear,
             .levelUp:
            return nil
        }
    }

    static func sounds(for event: ClearEvent, status: GameStatus) -> [GameSound] {
        var sounds: [GameSound] = []

        if let mainSound = mainSound(for: event.clearName) {
            sounds.append(mainSound)
        } else if event.scoreDelta > 0 {
            sounds.append(.hardDrop)
        }

        if event.backToBackBonusApplied {
            sounds.append(.backToBack)
        }
        if event.combo > 0 {
            sounds.append(.ren)
        }
        if status == .gameOver {
            sounds.append(.gameOver)
        }

        return sounds
    }

    private static func mainSound(for clearName: ClearName) -> GameSound? {
        switch clearName {
        case .none:
            return nil
        case .single:
            return .single
        case .double:
            return .double
        case .triple:
            return .triple
        case .tetris:
            return .tetris
        case .tSpinNoLine,
             .tSpinMini:
            return .tSpin
        case .tSpinSingle,
             .tSpinMiniSingle:
            return .tSpinSingle
        case .tSpinDouble,
             .tSpinMiniDouble:
            return .tSpinDouble
        case .tSpinTriple:
            return .tSpinTriple
        }
    }
}

@MainActor
protocol SoundPlaying: AnyObject {
    func play(_ sound: GameSound)
}

@MainActor
final class AppSoundPlayer: SoundPlaying {
    private let bundle: Bundle
    private var players: [GameSound: AVAudioPlayer] = [:]

    init(bundle: Bundle = .module) {
        self.bundle = bundle
        preloadBundledSounds()
    }

    func play(_ sound: GameSound) {
        if let player = players[sound] {
            player.currentTime = 0
            player.play()
            return
        }

        AudioServicesPlaySystemSound(fallbackSystemSoundID(for: sound))
    }

    func resourceURL(for sound: GameSound) -> URL? {
        guard let fileName = sound.resourceFileName else {
            return nil
        }
        return bundle.url(
            forResource: fileName,
            withExtension: "wav",
            subdirectory: "Assets/tetris_voice_assets"
        ) ?? bundle.url(forResource: fileName, withExtension: "wav")
    }

    private func preloadBundledSounds() {
        for sound in bundledSounds {
            guard let url = resourceURL(for: sound),
                  let data = try? Data(contentsOf: url),
                  let player = try? AVAudioPlayer(data: data) else {
                continue
            }
            player.prepareToPlay()
            players[sound] = player
        }
    }

    private var bundledSounds: [GameSound] {
        [
            .single,
            .double,
            .triple,
            .tetris,
            .tSpin,
            .tSpinSingle,
            .tSpinDouble,
            .tSpinTriple,
            .backToBack,
            .ren,
            .gameOver
        ]
    }

    private func fallbackSystemSoundID(for sound: GameSound) -> SystemSoundID {
        switch sound {
        case .levelUp:
            return 1025
        case .lineClear:
            return 1057
        default:
            return 1104
        }
    }
}

@MainActor
@Observable
final class GameViewModel {
    enum HorizontalDirection: Sendable {
        case left
        case right
    }

    private(set) var state: GameState
    private(set) var elapsedMilliseconds = 0
    private(set) var eventMessage = "READY"
    private(set) var clearEffect: ClearEffectToast?
    private(set) var recentScoreDelta: Int?
    var settings = GameSettings() {
        didSet {
            settingsStore.save(settings)
            applyGravitySetting()
        }
    }
    private(set) var isStarted = false
    private(set) var isPaused = false

    private var loopTask: Task<Void, Never>?
    private var horizontalHoldMilliseconds = 0.0
    private var horizontalRepeatMilliseconds = 0.0
    private var activeHorizontalDirection: HorizontalDirection?
    private var clearEffectID = 0
    private let fixedSeed: UInt64?
    private let soundPlayer: any SoundPlaying
    private let settingsStore: any GameSettingsPersisting

    init(
        seed: UInt64? = nil,
        soundPlayer: any SoundPlaying = AppSoundPlayer(),
        settingsStore: any GameSettingsPersisting = UserDefaultsGameSettingsStore()
    ) {
        fixedSeed = seed
        self.soundPlayer = soundPlayer
        self.settingsStore = settingsStore
        state = Self.standbyState()
        settings = settingsStore.load() ?? GameSettings()
        applyGravitySetting()
    }

    init(
        state: GameState,
        soundPlayer: any SoundPlaying = AppSoundPlayer(),
        settingsStore: any GameSettingsPersisting = UserDefaultsGameSettingsStore()
    ) {
        fixedSeed = nil
        self.soundPlayer = soundPlayer
        self.settingsStore = settingsStore
        self.state = state
        settings = settingsStore.load() ?? GameSettings()
        applyGravitySetting()
    }

    func startLoop() {
        guard loopTask == nil else {
            return
        }

        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                await self?.tick(deltaMilliseconds: 16)
            }
        }
    }

    func restart(mode: GameMode = .marathon) {
        state = Self.standbyState(mode: mode)
        applyGravitySetting()
        elapsedMilliseconds = 0
        eventMessage = "READY"
        clearEffect = nil
        recentScoreDelta = nil
        isStarted = false
        isPaused = false
        resetHorizontalInput()
        activeHorizontalDirection = nil
    }

    func start() {
        guard !isStarted else {
            return
        }

        let mode = state.mode
        state = GameState.newGame(seed: nextSeed(), visibleNextCount: 5, mode: mode)
        applyGravitySetting()
        isStarted = true
        isPaused = false
        eventMessage = "GO"
    }

    func togglePause() {
        guard isStarted, state.status == .playing else {
            return
        }

        isPaused.toggle()
        eventMessage = isPaused ? "PAUSED" : "RESUME"
    }

    func resume() {
        guard isStarted else {
            return
        }

        isPaused = false
        eventMessage = "RESUME"
    }

    func setHoldMoveMultiplier(_ value: Double) {
        updateSettings { settings in
            settings.holdMoveMultiplier = value
        }
    }

    func setGravityMultiplier(_ value: Double) {
        updateSettings { settings in
            settings.gravityMultiplier = value
        }
    }

    func setHorizontalAutoShiftDelayMilliseconds(_ value: Double) {
        updateSettings { settings in
            settings.horizontalAutoShiftDelayMilliseconds = value
        }
    }

    func setHorizontalAutoRepeatIntervalMilliseconds(_ value: Double) {
        updateSettings { settings in
            settings.horizontalAutoRepeatIntervalMilliseconds = value
        }
    }

    func bind(_ key: String, to action: GameInputAction) {
        updateSettings { settings in
            settings.bind(key, to: action)
        }
    }

    func moveLeft(isRepeat: Bool = false) {
        guard isStarted, !isPaused else { return }
        for _ in 0..<movementSteps(isRepeat: isRepeat) {
            moveHorizontally(.left)
        }
    }

    func moveRight(isRepeat: Bool = false) {
        guard isStarted, !isPaused else { return }
        for _ in 0..<movementSteps(isRepeat: isRepeat) {
            moveHorizontally(.right)
        }
    }

    func pressHorizontalInput(_ direction: HorizontalDirection) {
        guard isStarted, !isPaused else { return }
        if activeHorizontalDirection != direction {
            resetHorizontalInput()
            moveHorizontally(direction)
        }
        activeHorizontalDirection = direction
    }

    func releaseHorizontalInput(_ direction: HorizontalDirection) {
        guard activeHorizontalDirection == direction else {
            return
        }
        activeHorizontalDirection = nil
        resetHorizontalInput()
    }

    func softDrop() {
        guard isStarted, !isPaused else { return }
        _ = state.moveActivePiece(dx: 0, dy: -1)
    }

    func rotateClockwise() {
        guard isStarted, !isPaused else { return }
        _ = state.rotateActivePiece(.clockwise)
    }

    func rotateCounterClockwise() {
        guard isStarted, !isPaused else { return }
        _ = state.rotateActivePiece(.counterClockwise)
    }

    func hold() {
        guard isStarted, !isPaused else { return }
        _ = state.hold()
    }

    func hardDrop() {
        guard isStarted, !isPaused else { return }
        do {
            let previousLevel = state.level
            let event = try state.hardDrop()
            updateMessage(from: event, previousLevel: previousLevel)
        } catch {
            eventMessage = "LOCK ERROR"
        }
    }

    func tick(deltaMilliseconds: Int) async {
        guard isStarted, !isPaused, state.status == .playing else {
            return
        }

        do {
            applyHorizontalInput(deltaMilliseconds: deltaMilliseconds)
            let previousLevel = state.level
            if let event = try state.tick(deltaMilliseconds: deltaMilliseconds) {
                updateMessage(from: event, previousLevel: previousLevel)
            }
            elapsedMilliseconds += deltaMilliseconds
        } catch {
            eventMessage = "GAME ERROR"
        }
    }

    private func applyGravitySetting() {
        let baseInterval = 1_000
        let settingsMultiplier = min(max(settings.gravityMultiplier, 1.0), 2.0)
        let levelMultiplier = pow(0.86, Double(max(state.level - 1, 0)))
        let interval = max(Int(Double(baseInterval) * levelMultiplier / settingsMultiplier), 80)
        state.setGravityIntervalMilliseconds(interval)
    }

    private func updateSettings(_ update: (inout GameSettings) -> Void) {
        var updatedSettings = settings
        update(&updatedSettings)
        settings = updatedSettings
    }

    private static func standbyState(mode: GameMode = .marathon) -> GameState {
        GameState(
            status: .ready,
            mode: mode,
            board: Board(),
            activePiece: nil,
            holdPiece: nil,
            holdUsed: false,
            nextQueue: NextQueue(
                randomizer: SevenBagRandomizer(seed: 1),
                visibleCount: 5,
                prefill: false
            )
        )
    }

    private func nextSeed() -> UInt64 {
        fixedSeed ?? UInt64(Date().timeIntervalSince1970 * 1_000)
    }

    private func movementSteps(isRepeat: Bool) -> Int {
        guard isRepeat else {
            horizontalRepeatMilliseconds = 0
            return 1
        }

        horizontalRepeatMilliseconds += min(max(settings.holdMoveMultiplier, 1.0), 2.0)
        let steps = max(Int(horizontalRepeatMilliseconds), 1)
        horizontalRepeatMilliseconds -= Double(steps)
        return steps
    }

    private func applyHorizontalInput(deltaMilliseconds: Int) {
        guard let activeHorizontalDirection else {
            return
        }

        let previousHoldMilliseconds = horizontalHoldMilliseconds
        horizontalHoldMilliseconds += Double(max(deltaMilliseconds, 0))
        let delay = clampedAutoShiftDelay
        guard horizontalHoldMilliseconds >= delay else {
            return
        }

        let interval = clampedAutoRepeatInterval
        if previousHoldMilliseconds < delay {
            moveHorizontally(activeHorizontalDirection)
            horizontalRepeatMilliseconds = horizontalHoldMilliseconds - delay
        } else {
            horizontalRepeatMilliseconds += Double(max(deltaMilliseconds, 0))
        }

        while horizontalRepeatMilliseconds >= interval {
            moveHorizontally(activeHorizontalDirection)
            horizontalRepeatMilliseconds -= interval
        }
    }

    private var clampedAutoShiftDelay: Double {
        min(max(settings.horizontalAutoShiftDelayMilliseconds, 30), 500)
    }

    private var clampedAutoRepeatInterval: Double {
        min(max(settings.horizontalAutoRepeatIntervalMilliseconds, 10), 120)
    }

    private func resetHorizontalInput() {
        horizontalHoldMilliseconds = 0
        horizontalRepeatMilliseconds = 0
    }

    private func moveHorizontally(_ direction: HorizontalDirection) {
        switch direction {
        case .left:
            _ = state.moveActivePiece(dx: -1, dy: 0)
        case .right:
            _ = state.moveActivePiece(dx: 1, dy: 0)
        }
    }

    private func updateMessage(from event: ClearEvent, previousLevel: Int) {
        showScoreDelta(event.scoreDelta)
        for sound in GameSound.sounds(for: event, status: state.status) {
            soundPlayer.play(sound)
        }
        applyGravitySetting()
        if state.level > previousLevel {
            soundPlayer.play(.levelUp)
        }

        if event.clearName == .none {
            eventMessage = "LOCK"
            return
        }

        let main = displayName(for: event.clearName)
        let b2b = event.backToBackBonusApplied ? " B2B" : ""
        let combo = event.combo > 0 ? " REN \(event.combo)" : ""
        eventMessage = "\(main)\(b2b)\(combo)"
        showClearEffect(for: event, title: main)
    }

    private func showScoreDelta(_ scoreDelta: Int) {
        guard scoreDelta > 0 else {
            recentScoreDelta = nil
            return
        }

        recentScoreDelta = scoreDelta
        Task { [weak self, scoreDelta] in
            try? await Task.sleep(for: .milliseconds(900))
            guard let self, self.recentScoreDelta == scoreDelta else {
                return
            }
            self.recentScoreDelta = nil
        }
    }

    private func showClearEffect(for event: ClearEvent, title: String) {
        clearEffectID += 1
        let subtitleParts = [
            event.backToBackBonusApplied ? "Back-to-Back" : nil,
            event.combo > 0 ? "REN \(event.combo)" : nil,
            event.attack > 0 ? "+\(event.attack)" : nil
        ].compactMap { $0 }
        let kind: ClearEffectToast.Kind
        if event.spin != .none {
            kind = .tSpin
        } else if event.clearName == .tetris {
            kind = .tetris
        } else {
            kind = .normal
        }
        let effect = ClearEffectToast(
            id: clearEffectID,
            title: effectTitle(for: event.clearName, fallback: title),
            subtitle: subtitleParts.joined(separator: "  "),
            kind: kind
        )
        clearEffect = effect

        Task { [weak self, effectID = effect.id] in
            try? await Task.sleep(for: .milliseconds(900))
            guard let self, self.clearEffect?.id == effectID else {
                return
            }
            self.clearEffect = nil
        }
    }

    private func effectTitle(for clearName: ClearName, fallback: String) -> String {
        switch clearName {
        case .tSpinNoLine:
            return "T-Spin!"
        case .tSpinSingle:
            return "T-Spin Single!"
        case .tSpinDouble:
            return "T-Spin Double!"
        case .tSpinTriple:
            return "T-Spin Triple!"
        case .tSpinMini:
            return "T-Spin Mini!"
        case .tSpinMiniSingle:
            return "T-Spin Mini Single!"
        case .tSpinMiniDouble:
            return "T-Spin Mini Double!"
        case .tetris:
            return "Tetris!"
        case .single:
            return "Single"
        case .double:
            return "Double"
        case .triple:
            return "Triple"
        case .none:
            return fallback
        }
    }

    private func displayName(for clearName: ClearName) -> String {
        switch clearName {
        case .none:
            return ""
        case .single:
            return "SINGLE"
        case .double:
            return "DOUBLE"
        case .triple:
            return "TRIPLE"
        case .tetris:
            return "TETRIS"
        case .tSpinNoLine:
            return "T-SPIN"
        case .tSpinSingle:
            return "T-SPIN SINGLE"
        case .tSpinDouble:
            return "T-SPIN DOUBLE"
        case .tSpinTriple:
            return "T-SPIN TRIPLE"
        case .tSpinMini:
            return "T-SPIN MINI"
        case .tSpinMiniSingle:
            return "T-SPIN MINI SINGLE"
        case .tSpinMiniDouble:
            return "T-SPIN MINI DOUBLE"
        }
    }
}
