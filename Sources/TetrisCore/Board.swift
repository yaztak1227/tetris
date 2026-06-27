public enum BoardError: Error, Equatable {
    case outOfBounds(Cell)
}

public struct Board: Equatable, Sendable {
    public static let visibleWidth = 10
    public static let visibleHeight = 20
    public static let hiddenRows = 2

    public let width: Int
    public let height: Int
    private var blocks: [Cell: PieceType]

    public init(
        width: Int = Board.visibleWidth,
        visibleHeight: Int = Board.visibleHeight,
        hiddenRows: Int = Board.hiddenRows,
        blocks: [Cell: PieceType] = [:]
    ) {
        self.width = width
        self.height = visibleHeight + hiddenRows
        self.blocks = blocks
    }

    public func block(at cell: Cell) -> PieceType? {
        blocks[cell]
    }

    public func canPlace(_ piece: Piece) -> Bool {
        piece.cells.allSatisfy { isInside($0) && blocks[$0] == nil }
    }

    public mutating func set(_ pieceType: PieceType, at cell: Cell) throws {
        guard isInside(cell) else {
            throw BoardError.outOfBounds(cell)
        }
        blocks[cell] = pieceType
    }

    public mutating func lock(_ piece: Piece) throws {
        for cell in piece.cells {
            try set(piece.type, at: cell)
        }
    }

    public mutating func clearFullLines() -> [Int] {
        let fullRows = fullLines()

        guard !fullRows.isEmpty else {
            return []
        }

        var compacted: [Cell: PieceType] = [:]
        for (cell, pieceType) in blocks {
            guard !fullRows.contains(cell.y) else {
                continue
            }
            let rowsBelow = fullRows.filter { $0 < cell.y }.count
            compacted[Cell(x: cell.x, y: cell.y - rowsBelow)] = pieceType
        }
        blocks = compacted
        return fullRows
    }

    public func fullLines() -> [Int] {
        (0..<height).filter { y in
            (0..<width).allSatisfy { x in
                blocks[Cell(x: x, y: y)] != nil
            }
        }
    }

    public func isBlockedForSpin(at cell: Cell) -> Bool {
        guard isInside(cell) else {
            return true
        }
        return blocks[cell] != nil
    }

    private func isInside(_ cell: Cell) -> Bool {
        (0..<width).contains(cell.x) && (0..<height).contains(cell.y)
    }
}
