import XCTest
@testable import TetrisCore

final class BoardTests: XCTestCase {
    func testCollisionTreatsWallsAndFloorAsBlocked() {
        let board = Board()
        let piece = Piece(type: .o, origin: Cell(x: 0, y: 0), rotation: .north)

        XCTAssertTrue(board.canPlace(piece))
        XCTAssertFalse(board.canPlace(piece.movedBy(dx: -1, dy: 0)))
        XCTAssertFalse(board.canPlace(piece.movedBy(dx: 0, dy: -1)))
    }

    func testLineClearRemovesFullRowsAndDropsRowsAbove() throws {
        var board = Board()
        for x in 0..<Board.visibleWidth {
            try board.set(.i, at: Cell(x: x, y: 0))
        }
        try board.set(.t, at: Cell(x: 4, y: 1))

        let cleared = board.clearFullLines()

        XCTAssertEqual(cleared, [0])
        XCTAssertEqual(board.block(at: Cell(x: 4, y: 0)), .t)
        XCTAssertNil(board.block(at: Cell(x: 4, y: 1)))
    }
}
