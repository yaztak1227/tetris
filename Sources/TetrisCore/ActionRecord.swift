public enum ActionType: Sendable {
    case move
    case softDrop
    case hardDrop
    case rotate
    case hold
    case lock
}

public struct ActionRecord: Equatable, Sendable {
    public let type: ActionType
    public let pieceType: PieceType
    public let rotationFrom: RotationState?
    public let rotationTo: RotationState?
    public let kickIndex: Int?
    public let succeeded: Bool

    public init(
        type: ActionType,
        pieceType: PieceType,
        rotationFrom: RotationState? = nil,
        rotationTo: RotationState? = nil,
        kickIndex: Int? = nil,
        succeeded: Bool
    ) {
        self.type = type
        self.pieceType = pieceType
        self.rotationFrom = rotationFrom
        self.rotationTo = rotationTo
        self.kickIndex = kickIndex
        self.succeeded = succeeded
    }
}
