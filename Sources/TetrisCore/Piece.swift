public enum PieceType: CaseIterable, Hashable, Sendable {
    case i
    case o
    case t
    case s
    case z
    case j
    case l
}

public enum RotationState: Int, CaseIterable, Hashable, Sendable {
    case north = 0
    case east = 1
    case south = 2
    case west = 3
}

public struct Cell: Hashable, Sendable {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    public func movedBy(dx: Int, dy: Int) -> Cell {
        Cell(x: x + dx, y: y + dy)
    }
}

public struct Piece: Equatable, Sendable {
    public let type: PieceType
    public let origin: Cell
    public let rotation: RotationState

    public init(type: PieceType, origin: Cell, rotation: RotationState) {
        self.type = type
        self.origin = origin
        self.rotation = rotation
    }

    public var cells: [Cell] {
        offsets.map { origin.movedBy(dx: $0.x, dy: $0.y) }
    }

    public var tSpinCornerCells: [Cell] {
        [
            origin.movedBy(dx: -1, dy: -1),
            origin.movedBy(dx: 1, dy: -1),
            origin.movedBy(dx: -1, dy: 1),
            origin.movedBy(dx: 1, dy: 1)
        ]
    }

    public func movedBy(dx: Int, dy: Int) -> Piece {
        Piece(type: type, origin: origin.movedBy(dx: dx, dy: dy), rotation: rotation)
    }

    private var offsets: [Cell] {
        switch type {
        case .i:
            switch rotation {
            case .north, .south:
                return [Cell(x: -1, y: 0), Cell(x: 0, y: 0), Cell(x: 1, y: 0), Cell(x: 2, y: 0)]
            case .east, .west:
                return [Cell(x: 0, y: -1), Cell(x: 0, y: 0), Cell(x: 0, y: 1), Cell(x: 0, y: 2)]
            }
        case .o:
            return [Cell(x: 0, y: 0), Cell(x: 1, y: 0), Cell(x: 0, y: 1), Cell(x: 1, y: 1)]
        case .t:
            switch rotation {
            case .north:
                return [Cell(x: -1, y: 0), Cell(x: 0, y: 0), Cell(x: 1, y: 0), Cell(x: 0, y: 1)]
            case .east:
                return [Cell(x: 0, y: -1), Cell(x: 0, y: 0), Cell(x: 0, y: 1), Cell(x: 1, y: 0)]
            case .south:
                return [Cell(x: -1, y: 0), Cell(x: 0, y: 0), Cell(x: 1, y: 0), Cell(x: 0, y: -1)]
            case .west:
                return [Cell(x: 0, y: -1), Cell(x: 0, y: 0), Cell(x: 0, y: 1), Cell(x: -1, y: 0)]
            }
        case .s:
            switch rotation {
            case .north, .south:
                return [Cell(x: 0, y: 0), Cell(x: 1, y: 0), Cell(x: -1, y: 1), Cell(x: 0, y: 1)]
            case .east, .west:
                return [Cell(x: 0, y: -1), Cell(x: 0, y: 0), Cell(x: 1, y: 0), Cell(x: 1, y: 1)]
            }
        case .z:
            switch rotation {
            case .north, .south:
                return [Cell(x: -1, y: 0), Cell(x: 0, y: 0), Cell(x: 0, y: 1), Cell(x: 1, y: 1)]
            case .east, .west:
                return [Cell(x: 1, y: -1), Cell(x: 0, y: 0), Cell(x: 1, y: 0), Cell(x: 0, y: 1)]
            }
        case .j:
            switch rotation {
            case .north:
                return [Cell(x: -1, y: 0), Cell(x: 0, y: 0), Cell(x: 1, y: 0), Cell(x: -1, y: 1)]
            case .east:
                return [Cell(x: 0, y: -1), Cell(x: 0, y: 0), Cell(x: 0, y: 1), Cell(x: 1, y: 1)]
            case .south:
                return [Cell(x: -1, y: 0), Cell(x: 0, y: 0), Cell(x: 1, y: 0), Cell(x: 1, y: -1)]
            case .west:
                return [Cell(x: 0, y: -1), Cell(x: 0, y: 0), Cell(x: 0, y: 1), Cell(x: -1, y: -1)]
            }
        case .l:
            switch rotation {
            case .north:
                return [Cell(x: -1, y: 0), Cell(x: 0, y: 0), Cell(x: 1, y: 0), Cell(x: 1, y: 1)]
            case .east:
                return [Cell(x: 0, y: -1), Cell(x: 0, y: 0), Cell(x: 0, y: 1), Cell(x: 1, y: -1)]
            case .south:
                return [Cell(x: -1, y: 0), Cell(x: 0, y: 0), Cell(x: 1, y: 0), Cell(x: -1, y: -1)]
            case .west:
                return [Cell(x: 0, y: -1), Cell(x: 0, y: 0), Cell(x: 0, y: 1), Cell(x: -1, y: 1)]
            }
        }
    }
}
