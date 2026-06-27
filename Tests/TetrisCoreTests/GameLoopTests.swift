import XCTest
@testable import TetrisCore

final class GameLoopTests: XCTestCase {
    func testTickWaitsUntilGravityIntervalBeforeDropping() throws {
        var state = makeLoopState(
            activePiece: Piece(type: .t, origin: Cell(x: 4, y: 5), rotation: .north),
            gravityIntervalMilliseconds: 1_000
        )

        XCTAssertNil(try state.tick(deltaMilliseconds: 999))
        XCTAssertEqual(state.activePiece?.origin, Cell(x: 4, y: 5))

        XCTAssertNil(try state.tick(deltaMilliseconds: 1))
        XCTAssertEqual(state.activePiece?.origin, Cell(x: 4, y: 4))
        XCTAssertEqual(state.lastAction?.type, .softDrop)
    }

    func testNewGameTickDropsSpawnedPieceAfterGravityInterval() throws {
        var state = GameState.newGame(seed: 2026, visibleNextCount: 5)
        let originalOrigin = try XCTUnwrap(state.activePiece?.origin)

        XCTAssertNil(try state.tick(deltaMilliseconds: 1_000))

        XCTAssertEqual(state.activePiece?.origin, originalOrigin.movedBy(dx: 0, dy: -1))
    }

    func testTickUsesLockDelayWhenPieceIsGrounded() throws {
        var state = makeLoopState(
            activePiece: Piece(type: .o, origin: Cell(x: 4, y: 0), rotation: .north),
            gravityIntervalMilliseconds: 1_000,
            lockSettings: LockSettings(lockDelayMilliseconds: 500, maxResets: 15)
        )

        XCTAssertNil(try state.tick(deltaMilliseconds: 499))
        XCTAssertEqual(state.board.block(at: Cell(x: 4, y: 0)), nil)

        let event = try state.tick(deltaMilliseconds: 1)

        XCTAssertEqual(event?.clearedLines, 0)
        XCTAssertEqual(state.board.block(at: Cell(x: 4, y: 0)), .o)
        XCTAssertEqual(state.lastAction?.type, .lock)
    }

    func testGroundedMoveResetsLockDelay() throws {
        var state = makeLoopState(
            activePiece: Piece(type: .o, origin: Cell(x: 4, y: 0), rotation: .north),
            gravityIntervalMilliseconds: 1_000,
            lockSettings: LockSettings(lockDelayMilliseconds: 500, maxResets: 15)
        )

        XCTAssertNil(try state.tick(deltaMilliseconds: 400))
        XCTAssertTrue(state.moveActivePiece(dx: -1, dy: 0))
        XCTAssertNil(try state.tick(deltaMilliseconds: 400))
        XCTAssertEqual(state.board.block(at: Cell(x: 3, y: 0)), nil)

        _ = try state.tick(deltaMilliseconds: 100)

        XCTAssertEqual(state.board.block(at: Cell(x: 3, y: 0)), .o)
    }

    func testFortyLinesModeCompletesWhenTargetLinesReached() throws {
        var board = Board()
        for y in 0...1 {
            for x in 0..<Board.visibleWidth where x != 4 && x != 5 {
                try board.set(.i, at: Cell(x: x, y: y))
            }
        }
        var state = makeLoopState(
            mode: .fortyLines,
            board: board,
            activePiece: Piece(type: .o, origin: Cell(x: 4, y: 0), rotation: .north),
            totalClearedLines: 38
        )

        let event = try state.lockActivePiece()

        XCTAssertEqual(event.clearedLines, 2)
        XCTAssertEqual(state.totalClearedLines, 40)
        XCTAssertEqual(state.status, .completed)
    }

    private func makeLoopState(
        mode: GameMode = .marathon,
        board: Board = Board(),
        activePiece: Piece,
        totalClearedLines: Int = 0,
        gravityIntervalMilliseconds: Int = 1_000,
        lockSettings: LockSettings = LockSettings(),
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> GameState {
        let queue = NextQueue(randomizer: SevenBagRandomizer(seed: 101), visibleCount: 5)
        return GameState(
            status: .playing,
            mode: mode,
            board: board,
            activePiece: activePiece,
            holdPiece: nil,
            holdUsed: false,
            nextQueue: queue,
            totalClearedLines: totalClearedLines,
            gravityIntervalMilliseconds: gravityIntervalMilliseconds,
            lockController: LockController(settings: lockSettings)
        )
    }
}
