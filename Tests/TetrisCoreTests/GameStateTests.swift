import XCTest
@testable import TetrisCore

final class GameStateTests: XCTestCase {
    func testNewGameSpawnsActivePieceAndMaintainsNextPreview() {
        let state = GameState.newGame(seed: 10, visibleNextCount: 5)

        XCTAssertEqual(state.status, .playing)
        XCTAssertNotNil(state.activePiece)
        XCTAssertEqual(state.nextQueue.preview.count, 5)
        XCTAssertNil(state.holdPiece)
        XCTAssertFalse(state.holdUsed)
    }

    func testNewGameSpawnsActivePieceWithAtLeastOneVisibleCell() throws {
        let state = GameState.newGame(seed: 10, visibleNextCount: 5)
        let activePiece = try XCTUnwrap(state.activePiece)

        XCTAssertTrue(activePiece.cells.contains { (0..<Board.visibleHeight).contains($0.y) })
    }

    func testHoldStoresCurrentPieceAndSpawnsNextPiece() {
        var state = GameState.newGame(seed: 11, visibleNextCount: 5)
        let firstType = state.activePiece?.type
        let expectedNextType = state.nextQueue.preview.first

        XCTAssertTrue(state.hold())

        XCTAssertEqual(state.holdPiece, firstType)
        XCTAssertEqual(state.activePiece?.type, expectedNextType)
        XCTAssertTrue(state.holdUsed)
        XCTAssertEqual(state.lastAction?.type, .hold)
        XCTAssertTrue(state.lastAction?.succeeded == true)
    }

    func testHoldCanOnlyBeUsedOnceBeforeLock() {
        var state = GameState.newGame(seed: 12, visibleNextCount: 5)

        XCTAssertTrue(state.hold())
        let activeAfterFirstHold = state.activePiece
        let holdAfterFirstHold = state.holdPiece

        XCTAssertFalse(state.hold())

        XCTAssertEqual(state.activePiece, activeAfterFirstHold)
        XCTAssertEqual(state.holdPiece, holdAfterFirstHold)
        XCTAssertTrue(state.holdUsed)
        XCTAssertEqual(state.lastAction?.type, .hold)
        XCTAssertTrue(state.lastAction?.succeeded == false)
    }

    func testLockResetsHoldUseAndSpawnsNextPiece() throws {
        var state = GameState.newGame(seed: 13, visibleNextCount: 5)
        XCTAssertTrue(state.hold())
        let expectedNextAfterLock = state.nextQueue.preview.first

        let event = try state.lockActivePiece()

        XCTAssertEqual(event.clearedLines, 0)
        XCTAssertFalse(state.holdUsed)
        XCTAssertEqual(state.activePiece?.type, expectedNextAfterLock)
        XCTAssertEqual(state.lastAction?.type, .lock)
    }

    func testHardDropLocksImmediatelyAndScoresDropCells() throws {
        var state = GameState.newGame(seed: 14, visibleNextCount: 5)
        let originalType = try XCTUnwrap(state.activePiece?.type)

        let event = try state.hardDrop()

        XCTAssertEqual(event.clearedLines, 0)
        XCTAssertGreaterThan(event.scoreDelta, 0)
        XCTAssertEqual(state.board.block(at: Cell(x: 4, y: 0)), originalType)
        XCTAssertFalse(state.holdUsed)
        XCTAssertEqual(state.lastAction?.type, .lock)
    }

    func testMoveActivePieceUpdatesPositionAndLastAction() throws {
        var state = GameState.newGame(seed: 15, visibleNextCount: 5)
        let original = try XCTUnwrap(state.activePiece)

        XCTAssertTrue(state.moveActivePiece(dx: -1, dy: 0))

        XCTAssertEqual(state.activePiece?.origin, original.origin.movedBy(dx: -1, dy: 0))
        XCTAssertEqual(state.lastAction?.type, .move)
        XCTAssertTrue(state.lastAction?.succeeded == true)
    }

    func testMoveActivePieceFailsWhenCollidingWithWall() throws {
        var state = GameState.newGame(seed: 16, visibleNextCount: 5)

        while state.moveActivePiece(dx: -1, dy: 0) {}
        let wallPosition = try XCTUnwrap(state.activePiece)

        XCTAssertFalse(state.moveActivePiece(dx: -1, dy: 0))

        XCTAssertEqual(state.activePiece, wallPosition)
        XCTAssertEqual(state.lastAction?.type, .move)
        XCTAssertTrue(state.lastAction?.succeeded == false)
    }

    func testRotateActivePieceUsesSRSAndRecordsKick() throws {
        var state = GameState.newGame(seed: 17, visibleNextCount: 5)
        let piece = Piece(type: .t, origin: Cell(x: 1, y: 1), rotation: .north)
        var board = Board()
        try board.set(.z, at: Cell(x: 1, y: 0))
        state = GameState(
            status: .playing,
            board: board,
            activePiece: piece,
            holdPiece: nil,
            holdUsed: false,
            nextQueue: state.nextQueue
        )

        XCTAssertTrue(state.rotateActivePiece(.clockwise))

        XCTAssertEqual(state.activePiece?.rotation, .east)
        XCTAssertEqual(state.activePiece?.origin, Cell(x: 0, y: 1))
        XCTAssertEqual(state.lastAction?.type, .rotate)
        XCTAssertEqual(state.lastAction?.rotationFrom, .north)
        XCTAssertEqual(state.lastAction?.rotationTo, .east)
        XCTAssertEqual(state.lastAction?.kickIndex, 1)
    }
}
