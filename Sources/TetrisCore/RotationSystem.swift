public enum RotationDirection: Sendable {
    case clockwise
    case counterClockwise
    case oneEighty
}

public struct RotationResult: Equatable, Sendable {
    public let piece: Piece
    public let kickIndex: Int
}

public struct RotationSystem: Sendable {
    public static let srs = RotationSystem()

    public init() {}

    public func rotate(
        _ piece: Piece,
        direction: RotationDirection,
        on board: Board,
        isGrounded: Bool = true
    ) -> RotationResult? {
        let targetRotation = rotation(after: piece.rotation, direction: direction)
        let candidate = Piece(type: piece.type, origin: piece.origin, rotation: targetRotation)
        let kicks = kickOffsets(
            for: piece.type,
            from: piece.rotation,
            to: targetRotation,
            direction: direction,
            isGrounded: isGrounded
        )

        for (index, kick) in kicks.enumerated() {
            let kicked = candidate.movedBy(dx: kick.x, dy: kick.y)
            if board.canPlace(kicked) {
                return RotationResult(piece: kicked, kickIndex: index)
            }
        }

        return nil
    }

    private func rotation(after rotation: RotationState, direction: RotationDirection) -> RotationState {
        let offset: Int
        switch direction {
        case .clockwise:
            offset = 1
        case .counterClockwise:
            offset = -1
        case .oneEighty:
            offset = 2
        }

        let next = (rotation.rawValue + offset + RotationState.allCases.count) % RotationState.allCases.count
        return RotationState(rawValue: next) ?? .north
    }

    private func kickOffsets(
        for pieceType: PieceType,
        from: RotationState,
        to: RotationState,
        direction: RotationDirection,
        isGrounded: Bool
    ) -> [Cell] {
        guard direction != .oneEighty else {
            return [Cell(x: 0, y: 0)]
        }

        if pieceType == .o {
            return [Cell(x: 0, y: 0)]
        }

        if pieceType == .i {
            return iKicks(from: from, to: to)
        }

        let srsKicks = standardKicks(from: from, to: to)
        guard isGrounded else {
            return srsKicks
        }

        return srsKicks + groundedGapFitKicks(excluding: srsKicks)
    }

    private func groundedGapFitKicks(excluding existing: [Cell]) -> [Cell] {
        [
            Cell(x: 0, y: -1),
            Cell(x: -1, y: -1),
            Cell(x: 1, y: -1),
            Cell(x: 0, y: -2),
            Cell(x: -1, y: -2),
            Cell(x: 1, y: -2),
            Cell(x: 1, y: 0),
            Cell(x: -1, y: 0),
            Cell(x: 0, y: 1),
            Cell(x: 1, y: 1),
            Cell(x: -1, y: 1)
        ].filter { !existing.contains($0) }
    }

    private func standardKicks(from: RotationState, to: RotationState) -> [Cell] {
        switch (from, to) {
        case (.north, .east):
            return [Cell(x: 0, y: 0), Cell(x: -1, y: 0), Cell(x: -1, y: 1), Cell(x: 0, y: -2), Cell(x: -1, y: -2)]
        case (.east, .north):
            return [Cell(x: 0, y: 0), Cell(x: 1, y: 0), Cell(x: 1, y: -1), Cell(x: 0, y: 2), Cell(x: 1, y: 2)]
        case (.east, .south):
            return [Cell(x: 0, y: 0), Cell(x: 1, y: 0), Cell(x: 1, y: -1), Cell(x: 0, y: 2), Cell(x: 1, y: 2)]
        case (.south, .east):
            return [Cell(x: 0, y: 0), Cell(x: -1, y: 0), Cell(x: -1, y: 1), Cell(x: 0, y: -2), Cell(x: -1, y: -2)]
        case (.south, .west):
            return [Cell(x: 0, y: 0), Cell(x: 1, y: 0), Cell(x: 1, y: 1), Cell(x: 0, y: -2), Cell(x: 1, y: -2)]
        case (.west, .south):
            return [Cell(x: 0, y: 0), Cell(x: 1, y: 0), Cell(x: -1, y: 0), Cell(x: 1, y: -1), Cell(x: 0, y: 2), Cell(x: -1, y: 2)]
        case (.west, .north):
            return [Cell(x: 0, y: 0), Cell(x: 1, y: 0), Cell(x: -1, y: 0), Cell(x: 1, y: -1), Cell(x: 0, y: 2), Cell(x: -1, y: 2)]
        case (.north, .west):
            return [Cell(x: 0, y: 0), Cell(x: 1, y: 0), Cell(x: 1, y: 1), Cell(x: 0, y: -2), Cell(x: 1, y: -2)]
        default:
            return [Cell(x: 0, y: 0)]
        }
    }

    private func iKicks(from: RotationState, to: RotationState) -> [Cell] {
        switch (from, to) {
        case (.north, .east):
            return [Cell(x: 0, y: 0), Cell(x: -2, y: 0), Cell(x: 1, y: 0), Cell(x: -2, y: -1), Cell(x: 1, y: 2)]
        case (.east, .north):
            return [Cell(x: 0, y: 0), Cell(x: 1, y: 0), Cell(x: -2, y: 0), Cell(x: 1, y: 1), Cell(x: -2, y: -2)]
        case (.east, .south):
            return [Cell(x: 0, y: 0), Cell(x: -2, y: 0), Cell(x: 1, y: 0), Cell(x: -2, y: 2), Cell(x: 1, y: -1)]
        case (.south, .east):
            return [Cell(x: 0, y: 0), Cell(x: 1, y: 0), Cell(x: -2, y: 0), Cell(x: 1, y: -2), Cell(x: -2, y: 1)]
        case (.south, .west):
            return [Cell(x: 0, y: 0), Cell(x: 2, y: 0), Cell(x: -1, y: 0), Cell(x: 2, y: 1), Cell(x: -1, y: -2)]
        case (.west, .south):
            return [Cell(x: 0, y: 0), Cell(x: -2, y: 0), Cell(x: 1, y: 0), Cell(x: -2, y: -1), Cell(x: 1, y: 2)]
        case (.west, .north):
            return [Cell(x: 0, y: 0), Cell(x: 1, y: 0), Cell(x: -2, y: 0), Cell(x: 1, y: -2), Cell(x: -2, y: 1)]
        case (.north, .west):
            return [Cell(x: 0, y: 0), Cell(x: -1, y: 0), Cell(x: 2, y: 0), Cell(x: -1, y: 2), Cell(x: 2, y: -1)]
        default:
            return [Cell(x: 0, y: 0)]
        }
    }
}
