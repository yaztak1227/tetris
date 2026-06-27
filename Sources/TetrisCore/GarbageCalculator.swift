public struct GarbageLine: Equatable, Sendable {
    public let holeColumn: Int

    public init(holeColumn: Int) {
        self.holeColumn = holeColumn
    }
}

public struct GarbageResult: Equatable, Sendable {
    public let outgoingAttack: Int
    public let canceledIncoming: Int
    public let remainingIncoming: [GarbageLine]
}

public struct GarbageCalculator: Sendable {
    public static let standard = GarbageCalculator()

    public init() {}

    public func calculate(event: ClearEvent, incomingGarbage: [GarbageLine]) -> GarbageResult {
        let totalAttack = baseAttack(for: event.clearName)
            + backToBackBonus(for: event)
            + comboBonus(combo: event.combo)
        let canceled = min(totalAttack, incomingGarbage.count)
        let outgoing = totalAttack - canceled
        let remaining = Array(incomingGarbage.dropFirst(canceled))

        return GarbageResult(
            outgoingAttack: outgoing,
            canceledIncoming: canceled,
            remainingIncoming: remaining
        )
    }

    private func baseAttack(for clearName: ClearName) -> Int {
        switch clearName {
        case .none, .single, .tSpinNoLine, .tSpinMini:
            return 0
        case .double:
            return 1
        case .triple:
            return 2
        case .tetris:
            return 4
        case .tSpinSingle, .tSpinMiniSingle:
            return 2
        case .tSpinDouble, .tSpinMiniDouble:
            return 4
        case .tSpinTriple:
            return 6
        }
    }

    private func backToBackBonus(for event: ClearEvent) -> Int {
        event.backToBackBonusApplied ? 1 : 0
    }

    private func comboBonus(combo: Int) -> Int {
        guard combo >= 2 else {
            return 0
        }
        switch combo {
        case 2:
            return 1
        case 3...4:
            return 2
        case 5...6:
            return 3
        default:
            return 4
        }
    }
}
