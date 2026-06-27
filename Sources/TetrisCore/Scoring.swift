public enum ClearName: Equatable, Sendable {
    case none
    case single
    case double
    case triple
    case tetris
    case tSpinNoLine
    case tSpinSingle
    case tSpinDouble
    case tSpinTriple
    case tSpinMini
    case tSpinMiniSingle
    case tSpinMiniDouble
}

public struct ScoreInput: Sendable {
    public let spin: SpinKind
    public let clearedLines: Int
    public let hardDropCells: Int
    public let softDropCells: Int
    public let previousCombo: Int
    public let previousBackToBack: Bool
    public let level: Int

    public init(
        spin: SpinKind,
        clearedLines: Int,
        hardDropCells: Int,
        softDropCells: Int,
        previousCombo: Int,
        previousBackToBack: Bool,
        level: Int
    ) {
        self.spin = spin
        self.clearedLines = clearedLines
        self.hardDropCells = hardDropCells
        self.softDropCells = softDropCells
        self.previousCombo = previousCombo
        self.previousBackToBack = previousBackToBack
        self.level = level
    }
}

public struct ScoreResult: Sendable {
    public let clearName: ClearName
    public let scoreDelta: Int
    public let nextCombo: Int
    public let nextBackToBack: Bool
    public let backToBackBonusApplied: Bool
}

public struct ScoringSystem: Sendable {
    public static let standard = ScoringSystem()

    public init() {}

    public func score(_ input: ScoreInput) -> ScoreResult {
        let clearName = clearName(spin: input.spin, clearedLines: input.clearedLines)
        let baseScore = baseScore(for: clearName)
        let b2bEligible = isBackToBackEligible(clearName)
        let backToBackBonusApplied = input.previousBackToBack && b2bEligible
        let leveledScore = baseScore * max(input.level, 1)
        let clearScore = backToBackBonusApplied ? leveledScore * 3 / 2 : leveledScore
        let dropScore = input.hardDropCells * 2 + input.softDropCells
        let nextCombo = input.clearedLines > 0 ? input.previousCombo + 1 : -1
        let nextBackToBack: Bool
        if b2bEligible {
            nextBackToBack = true
        } else if input.clearedLines > 0 {
            nextBackToBack = false
        } else {
            nextBackToBack = input.previousBackToBack
        }

        return ScoreResult(
            clearName: clearName,
            scoreDelta: clearScore + dropScore,
            nextCombo: nextCombo,
            nextBackToBack: nextBackToBack,
            backToBackBonusApplied: backToBackBonusApplied
        )
    }

    private func clearName(spin: SpinKind, clearedLines: Int) -> ClearName {
        switch (spin, clearedLines) {
        case (.none, 0):
            return .none
        case (.none, 1):
            return .single
        case (.none, 2):
            return .double
        case (.none, 3):
            return .triple
        case (.none, _):
            return .tetris
        case (.tSpin, 0):
            return .tSpinNoLine
        case (.tSpin, 1):
            return .tSpinSingle
        case (.tSpin, 2):
            return .tSpinDouble
        case (.tSpin, _):
            return .tSpinTriple
        case (.tSpinMini, 0):
            return .tSpinMini
        case (.tSpinMini, 1):
            return .tSpinMiniSingle
        case (.tSpinMini, _):
            return .tSpinMiniDouble
        }
    }

    private func baseScore(for clearName: ClearName) -> Int {
        switch clearName {
        case .none:
            return 0
        case .single:
            return 100
        case .double:
            return 300
        case .triple:
            return 500
        case .tetris:
            return 800
        case .tSpinNoLine:
            return 400
        case .tSpinSingle:
            return 800
        case .tSpinDouble:
            return 1_200
        case .tSpinTriple:
            return 1_600
        case .tSpinMini:
            return 100
        case .tSpinMiniSingle:
            return 200
        case .tSpinMiniDouble:
            return 400
        }
    }

    private func isBackToBackEligible(_ clearName: ClearName) -> Bool {
        switch clearName {
        case .tetris, .tSpinSingle, .tSpinDouble, .tSpinTriple:
            return true
        case .none,
             .single,
             .double,
             .triple,
             .tSpinNoLine,
             .tSpinMini,
             .tSpinMiniSingle,
             .tSpinMiniDouble:
            return false
        }
    }
}
