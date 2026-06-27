import XCTest
@testable import TetrisCore

final class RotationSystemTests: XCTestCase {
    func testClockwiseRotationUsesFirstValidSRSKick() throws {
        var board = Board()
        try board.set(.z, at: Cell(x: 1, y: 0))
        let piece = Piece(type: .t, origin: Cell(x: 1, y: 1), rotation: .north)

        let result = RotationSystem.srs.rotate(piece, direction: .clockwise, on: board)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.piece.rotation, .east)
        XCTAssertEqual(result?.piece.origin, Cell(x: 0, y: 1))
        XCTAssertEqual(result?.kickIndex, 1)
    }

    func testRotationFailsWhenEveryKickCollides() throws {
        var board = Board()
        let piece = Piece(type: .t, origin: Cell(x: 1, y: 1), rotation: .north)
        let targetCells = [
            Cell(x: 1, y: 0),
            Cell(x: 0, y: 0),
            Cell(x: 0, y: 2),
            Cell(x: 1, y: -1),
            Cell(x: 0, y: -1),
            Cell(x: 2, y: 1),
            Cell(x: 1, y: 2)
        ]

        for cell in targetCells where cell.y >= 0 {
            try board.set(.z, at: cell)
        }

        XCTAssertNil(RotationSystem.srs.rotate(piece, direction: .clockwise, on: board))
    }

    func testNonIPieceUsesSRSWallKickWhileAirborne() {
        let board = Board()
        let piece = Piece(type: .j, origin: Cell(x: 0, y: 5), rotation: .north)

        let result = RotationSystem.srs.rotate(
            piece,
            direction: .counterClockwise,
            on: board,
            isGrounded: false
        )

        XCTAssertEqual(result?.piece.rotation, .west)
        XCTAssertEqual(result?.piece.origin, Cell(x: 1, y: 5))
        XCTAssertEqual(result?.kickIndex, 1)
    }

    func testIPieceCanRotateFromVerticalAtRightWallWhenSpaceIsOpen() {
        let board = Board()
        let piece = Piece(type: .i, origin: Cell(x: 9, y: 5), rotation: .east)

        let clockwise = RotationSystem.srs.rotate(
            piece,
            direction: .clockwise,
            on: board,
            isGrounded: false
        )
        let counterClockwise = RotationSystem.srs.rotate(
            piece,
            direction: .counterClockwise,
            on: board,
            isGrounded: false
        )

        XCTAssertNotNil(clockwise)
        XCTAssertEqual(clockwise?.piece.rotation, .south)
        XCTAssertEqual(clockwise?.piece.origin, Cell(x: 7, y: 5))
        XCTAssertNotNil(counterClockwise)
        XCTAssertEqual(counterClockwise?.piece.rotation, .north)
        XCTAssertEqual(counterClockwise?.piece.origin, Cell(x: 7, y: 5))
    }

    func testEveryPieceCanRotateAtBothWallsWhenSpaceIsOpen() throws {
        let board = Board()

        for pieceType in PieceType.allCases where pieceType != .o {
            for rotation in RotationState.allCases {
                for edgePiece in try wallPieces(for: pieceType, rotation: rotation, on: board) {
                    for direction in [RotationDirection.clockwise, .counterClockwise] {
                        let result = RotationSystem.srs.rotate(
                            edgePiece,
                            direction: direction,
                            on: board,
                            isGrounded: false
                        )

                        XCTAssertNotNil(
                            result,
                            "\(pieceType) \(rotation) failed \(direction) from \(edgePiece.origin)"
                        )
                    }
                }
            }
        }
    }

    func testGroundedTPieceCanUseNearbyOneCellSpinFitAfterSRSFails() throws {
        var board = Board()
        let piece = Piece(type: .t, origin: Cell(x: 4, y: 5), rotation: .north)
        let blockers = [
            Cell(x: 4, y: 4),
            Cell(x: 3, y: 4),
            Cell(x: 3, y: 7),
            Cell(x: 5, y: 3),
            Cell(x: 3, y: 2)
        ]

        for blocker in blockers {
            try board.set(.z, at: blocker)
        }

        let result = RotationSystem.srs.rotate(
            piece,
            direction: .clockwise,
            on: board,
            isGrounded: true
        )

        XCTAssertEqual(result?.piece.rotation, .east)
        XCTAssertEqual(result?.piece.origin, Cell(x: 5, y: 5))
    }

    func testGroundedLPieceChecksLowerGapFitsAfterSRSFails() throws {
        var board = Board()
        let piece = Piece(type: .l, origin: Cell(x: 4, y: 5), rotation: .north)
        let blockers = [
            Cell(x: 4, y: 6),
            Cell(x: 3, y: 4),
            Cell(x: 3, y: 7),
            Cell(x: 5, y: 2),
            Cell(x: 3, y: 3)
        ]

        for blocker in blockers {
            try board.set(.z, at: blocker)
        }

        let result = RotationSystem.srs.rotate(
            piece,
            direction: .clockwise,
            on: board,
            isGrounded: true
        )

        XCTAssertEqual(result?.piece.rotation, .east)
        XCTAssertEqual(result?.piece.origin, Cell(x: 4, y: 4))
    }

    private func wallPieces(
        for pieceType: PieceType,
        rotation: RotationState,
        on board: Board
    ) throws -> [Piece] {
        let candidates = (-2...11)
            .map { Piece(type: pieceType, origin: Cell(x: $0, y: 8), rotation: rotation) }
            .filter(board.canPlace)

        let left = try XCTUnwrap(candidates.first { piece in
            piece.cells.map(\.x).min() == 0
        })
        let right = try XCTUnwrap(candidates.first { piece in
            piece.cells.map(\.x).max() == board.width - 1
        })

        return left == right ? [left] : [left, right]
    }
}
