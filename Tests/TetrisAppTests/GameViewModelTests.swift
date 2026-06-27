import XCTest
@testable import TetrisApp
import TetrisCore

@MainActor
final class GameViewModelTests: XCTestCase {
    private final class RecordingSoundPlayer: SoundPlaying {
        private(set) var sounds: [GameSound] = []

        func play(_ sound: GameSound) {
            sounds.append(sound)
        }
    }

    private final class MemorySettingsStore: GameSettingsPersisting {
        var settings: GameSettings?

        init(settings: GameSettings? = nil) {
            self.settings = settings
        }

        func load() -> GameSettings? {
            settings
        }

        func save(_ settings: GameSettings) {
            self.settings = settings
        }
    }

    func testNewViewModelWaitsForStartBeforeAcceptingMovement() {
        let viewModel = GameViewModel(seed: 2026)

        viewModel.moveLeft()

        XCTAssertFalse(viewModel.isStarted)
        XCTAssertNil(viewModel.state.activePiece)
        XCTAssertEqual(viewModel.state.nextQueue.preview, [])
        XCTAssertEqual(viewModel.elapsedMilliseconds, 0)
    }

    func testStartGeneratesInitialPieceAndAllowsMovement() {
        let viewModel = GameViewModel(seed: 2026)

        viewModel.start()

        XCTAssertTrue(viewModel.isStarted)
        XCTAssertNotNil(viewModel.state.activePiece)
        XCTAssertEqual(viewModel.state.nextQueue.preview.count, 5)

        let startedOrigin = viewModel.state.activePiece?.origin
        viewModel.moveLeft()

        XCTAssertNotEqual(viewModel.state.activePiece?.origin, startedOrigin)
    }

    func testStartDoesNotResetAnActiveGame() {
        let viewModel = GameViewModel(seed: 2026)

        viewModel.start()
        let previewAfterStart = viewModel.state.nextQueue.preview
        viewModel.moveLeft()
        let activeAfterMove = viewModel.state.activePiece

        viewModel.start()

        XCTAssertTrue(viewModel.isStarted)
        XCTAssertEqual(viewModel.state.activePiece, activeAfterMove)
        XCTAssertEqual(viewModel.state.nextQueue.preview, previewAfterStart)
    }

    func testPauseBlocksMovement() {
        let viewModel = GameViewModel(seed: 2026)

        viewModel.start()
        viewModel.moveLeft()

        let pausedOrigin = viewModel.state.activePiece?.origin
        viewModel.togglePause()
        viewModel.moveLeft()

        XCTAssertTrue(viewModel.isPaused)
        XCTAssertEqual(viewModel.state.activePiece?.origin, pausedOrigin)
    }

    func testHorizontalHoldContinuesAfterRotationInput() async {
        let viewModel = GameViewModel(seed: 2026)

        viewModel.start()
        viewModel.settings.horizontalAutoShiftDelayMilliseconds = 50
        viewModel.settings.horizontalAutoRepeatIntervalMilliseconds = 40
        viewModel.pressHorizontalInput(.right)
        viewModel.rotateClockwise()
        let originAfterRotation = viewModel.state.activePiece?.origin

        await viewModel.tick(deltaMilliseconds: 50)

        XCTAssertEqual(
            viewModel.state.activePiece?.origin.x,
            originAfterRotation.map { $0.x + 1 }
        )
    }

    func testHorizontalHoldWaitsForConfiguredDelayBeforeRepeating() async {
        let viewModel = GameViewModel(seed: 2026)

        viewModel.start()
        viewModel.settings.horizontalAutoShiftDelayMilliseconds = 60
        viewModel.settings.horizontalAutoRepeatIntervalMilliseconds = 20
        viewModel.pressHorizontalInput(.right)
        let originAfterPress = viewModel.state.activePiece?.origin

        await viewModel.tick(deltaMilliseconds: 59)

        XCTAssertEqual(viewModel.state.activePiece?.origin, originAfterPress)

        await viewModel.tick(deltaMilliseconds: 1)

        XCTAssertEqual(
            viewModel.state.activePiece?.origin.x,
            originAfterPress.map { $0.x + 1 }
        )
    }

    func testHorizontalRepeatIntervalControlsHoldMovementSpeed() async {
        let slowViewModel = GameViewModel(seed: 2026)
        let fastViewModel = GameViewModel(seed: 2026)

        slowViewModel.start()
        fastViewModel.start()
        slowViewModel.settings.horizontalAutoShiftDelayMilliseconds = 40
        slowViewModel.settings.horizontalAutoRepeatIntervalMilliseconds = 80
        fastViewModel.settings.horizontalAutoShiftDelayMilliseconds = 40
        fastViewModel.settings.horizontalAutoRepeatIntervalMilliseconds = 20
        slowViewModel.pressHorizontalInput(.right)
        fastViewModel.pressHorizontalInput(.right)

        await slowViewModel.tick(deltaMilliseconds: 120)
        await fastViewModel.tick(deltaMilliseconds: 120)

        XCTAssertGreaterThan(
            fastViewModel.state.activePiece?.origin.x ?? 0,
            slowViewModel.state.activePiece?.origin.x ?? 0
        )
    }

    func testHorizontalHoldDelayAllowsTenMillisecondStepsUpToFiveHundredMilliseconds() async {
        let viewModel = GameViewModel(seed: 2026)

        viewModel.start()
        viewModel.settings.horizontalAutoShiftDelayMilliseconds = 500
        viewModel.settings.horizontalAutoRepeatIntervalMilliseconds = 20
        viewModel.pressHorizontalInput(.right)
        let originAfterPress = viewModel.state.activePiece?.origin

        await viewModel.tick(deltaMilliseconds: 490)

        XCTAssertEqual(viewModel.state.activePiece?.origin, originAfterPress)

        await viewModel.tick(deltaMilliseconds: 10)

        XCTAssertEqual(
            viewModel.state.activePiece?.origin.x,
            originAfterPress.map { $0.x + 1 }
        )
    }

    func testRestartReturnsToStartOverlayState() {
        let viewModel = GameViewModel(seed: 2026)

        viewModel.start()
        viewModel.togglePause()
        viewModel.restart()

        XCTAssertFalse(viewModel.isStarted)
        XCTAssertFalse(viewModel.isPaused)
        XCTAssertNil(viewModel.state.activePiece)
        XCTAssertEqual(viewModel.state.nextQueue.preview, [])
        XCTAssertEqual(viewModel.elapsedMilliseconds, 0)
        XCTAssertEqual(viewModel.eventMessage, "READY")
    }

    func testSettingsChangesArePersistedAndLoadedByNextViewModel() {
        let store = MemorySettingsStore()
        let viewModel = GameViewModel(
            seed: 2026,
            soundPlayer: RecordingSoundPlayer(),
            settingsStore: store
        )

        viewModel.settings.gravityMultiplier = 1.7
        viewModel.settings.horizontalAutoShiftDelayMilliseconds = 410
        viewModel.settings.bind("space", to: .start)

        let nextViewModel = GameViewModel(
            seed: 2026,
            soundPlayer: RecordingSoundPlayer(),
            settingsStore: store
        )

        XCTAssertEqual(nextViewModel.settings.gravityMultiplier, 1.7)
        XCTAssertEqual(nextViewModel.settings.horizontalAutoShiftDelayMilliseconds, 410)
        XCTAssertEqual(nextViewModel.settings.action(for: "space"), .start)
    }

    func testViewModelSettingUpdateMethodsPersistChanges() {
        let store = MemorySettingsStore()
        let viewModel = GameViewModel(
            seed: 2026,
            soundPlayer: RecordingSoundPlayer(),
            settingsStore: store
        )

        viewModel.setGravityMultiplier(1.6)
        viewModel.setHorizontalAutoShiftDelayMilliseconds(230)
        viewModel.setHorizontalAutoRepeatIntervalMilliseconds(70)
        viewModel.setHoldMoveMultiplier(1.2)
        viewModel.bind("space", to: .start)

        let saved = store.settings
        XCTAssertEqual(saved?.gravityMultiplier, 1.6)
        XCTAssertEqual(saved?.horizontalAutoShiftDelayMilliseconds, 230)
        XCTAssertEqual(saved?.horizontalAutoRepeatIntervalMilliseconds, 70)
        XCTAssertEqual(saved?.holdMoveMultiplier, 1.2)
        XCTAssertEqual(saved?.action(for: "space"), .start)
    }

    func testHardDropShowsScoreDeltaInScorePanelStateWithoutReplacingEventWithPoints() {
        let soundPlayer = RecordingSoundPlayer()
        let viewModel = GameViewModel(
            seed: 2026,
            soundPlayer: soundPlayer,
            settingsStore: MemorySettingsStore()
        )

        viewModel.start()
        viewModel.hardDrop()

        XCTAssertGreaterThan(viewModel.recentScoreDelta ?? 0, 0)
        XCTAssertEqual(viewModel.eventMessage, "LOCK")
        XCTAssertEqual(soundPlayer.sounds, [.hardDrop])
    }

    func testTetrisBackToBackRenQueuesVoiceSoundsInPriorityOrder() {
        let event = ClearEvent(
            clearedLines: 4,
            spin: .none,
            clearName: .tetris,
            scoreDelta: 1_200,
            attack: 5,
            combo: 2,
            backToBack: true,
            backToBackBonusApplied: true
        )

        XCTAssertEqual(
            GameSound.sounds(for: event, status: .playing),
            [.tetris, .backToBack, .ren]
        )
    }

    func testTSpinDoubleUsesBundledVoiceAssetName() {
        XCTAssertEqual(GameSound.tSpinDouble.resourceFileName, "t_spin_double")
    }

    func testBundledSoundPlayerResolvesVoiceAssetURL() throws {
        let soundPlayer = AppSoundPlayer(bundle: .module)

        let url = try XCTUnwrap(soundPlayer.resourceURL(for: .tSpinSingle))

        XCTAssertEqual(url.lastPathComponent, "t_spin_single.wav")
    }

    func testHigherLevelUsesFasterGravityInterval() {
        let levelOneState = makeState(level: 1)
        let levelFiveState = makeState(level: 5)

        let levelOneViewModel = GameViewModel(
            state: levelOneState,
            soundPlayer: RecordingSoundPlayer(),
            settingsStore: MemorySettingsStore()
        )
        let levelFiveViewModel = GameViewModel(
            state: levelFiveState,
            soundPlayer: RecordingSoundPlayer(),
            settingsStore: MemorySettingsStore()
        )

        XCTAssertLessThan(
            levelFiveViewModel.state.gravityIntervalMilliseconds,
            levelOneViewModel.state.gravityIntervalMilliseconds
        )
    }

    private func makeState(level: Int) -> GameState {
        GameState(
            status: .playing,
            board: Board(),
            activePiece: Piece(type: .t, origin: Cell(x: 4, y: 18), rotation: .north),
            holdPiece: nil,
            holdUsed: false,
            nextQueue: NextQueue(randomizer: SevenBagRandomizer(seed: 2026), visibleCount: 5),
            level: level,
            totalClearedLines: (level - 1) * 10
        )
    }
}
