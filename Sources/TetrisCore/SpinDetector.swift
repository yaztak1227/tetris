public enum SpinKind: Equatable, Sendable {
    case none
    case tSpin
    case tSpinMini
}

public enum SpinDetector {
    public static func detectSpin(board: Board, piece: Piece, lastAction: ActionRecord?) -> SpinKind {
        guard piece.type == .t,
              let lastAction,
              lastAction.type == .rotate,
              lastAction.pieceType == .t,
              lastAction.succeeded else {
            return .none
        }

        let blockedCorners = piece.tSpinCornerCells.filter { board.isBlockedForSpin(at: $0) }.count
        return blockedCorners >= 3 ? .tSpin : .none
    }
}
