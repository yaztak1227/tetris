import XCTest
@testable import TetrisCore

final class SpinDetectionTests: XCTestCase {
    func testDetectsTSpinWhenLastSuccessfulActionWasRotationAndThreeCornersAreBlocked() throws {
        var board = Board()
        let piece = Piece(type: .t, origin: Cell(x: 4, y: 1), rotation: .north)
        try board.set(.j, at: Cell(x: 3, y: 0))
        try board.set(.j, at: Cell(x: 5, y: 0))
        try board.set(.j, at: Cell(x: 3, y: 2))

        let action = ActionRecord(
            type: .rotate,
            pieceType: .t,
            rotationFrom: .west,
            rotationTo: .north,
            kickIndex: 0,
            succeeded: true
        )

        XCTAssertEqual(SpinDetector.detectSpin(board: board, piece: piece, lastAction: action), .tSpin)
    }

    func testDoesNotDetectTSpinForNonRotationLastAction() throws {
        var board = Board()
        let piece = Piece(type: .t, origin: Cell(x: 4, y: 1), rotation: .north)
        try board.set(.j, at: Cell(x: 3, y: 0))
        try board.set(.j, at: Cell(x: 5, y: 0))
        try board.set(.j, at: Cell(x: 3, y: 2))

        let action = ActionRecord(type: .move, pieceType: .t, succeeded: true)

        XCTAssertEqual(SpinDetector.detectSpin(board: board, piece: piece, lastAction: action), .none)
    }
}
