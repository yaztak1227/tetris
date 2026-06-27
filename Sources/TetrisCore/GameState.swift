public enum GameStatus: Equatable, Sendable {
    case ready
    case playing
    case paused
    case gameOver
    case completed
}

public enum GameMode: Equatable, Sendable {
    case marathon
    case fortyLines
    case practice
}

public struct ClearEvent: Equatable, Sendable {
    public let clearedLines: Int
    public let spin: SpinKind
    public let clearName: ClearName
    public let scoreDelta: Int
    public let attack: Int
    public let combo: Int
    public let backToBack: Bool
    public let backToBackBonusApplied: Bool

    public init(
        clearedLines: Int,
        spin: SpinKind,
        clearName: ClearName,
        scoreDelta: Int,
        attack: Int,
        combo: Int,
        backToBack: Bool,
        backToBackBonusApplied: Bool
    ) {
        self.clearedLines = clearedLines
        self.spin = spin
        self.clearName = clearName
        self.scoreDelta = scoreDelta
        self.attack = attack
        self.combo = combo
        self.backToBack = backToBack
        self.backToBackBonusApplied = backToBackBonusApplied
    }
}

public enum GameStateError: Error, Equatable {
    case noActivePiece
    case invalidLockPosition
}

public struct GameState: Sendable {
    public private(set) var status: GameStatus
    public private(set) var mode: GameMode
    public private(set) var board: Board
    public private(set) var activePiece: Piece?
    public private(set) var holdPiece: PieceType?
    public private(set) var holdUsed: Bool
    public private(set) var nextQueue: NextQueue
    public private(set) var score: Int
    public private(set) var level: Int
    public private(set) var totalClearedLines: Int
    public private(set) var combo: Int
    public private(set) var backToBack: Bool
    public private(set) var lastAction: ActionRecord?
    public private(set) var lastClearEvent: ClearEvent?
    public private(set) var gravityIntervalMilliseconds: Int
    public private(set) var gravityAccumulatorMilliseconds: Int
    public private(set) var lockController: LockController

    public init(
        status: GameStatus,
        mode: GameMode = .marathon,
        board: Board,
        activePiece: Piece?,
        holdPiece: PieceType?,
        holdUsed: Bool,
        nextQueue: NextQueue,
        score: Int = 0,
        level: Int = 1,
        totalClearedLines: Int = 0,
        combo: Int = -1,
        backToBack: Bool = false,
        lastAction: ActionRecord? = nil,
        lastClearEvent: ClearEvent? = nil,
        gravityIntervalMilliseconds: Int = 1_000,
        gravityAccumulatorMilliseconds: Int = 0,
        lockController: LockController = LockController()
    ) {
        self.status = status
        self.mode = mode
        self.board = board
        self.activePiece = activePiece
        self.holdPiece = holdPiece
        self.holdUsed = holdUsed
        self.nextQueue = nextQueue
        self.score = score
        self.level = level
        self.totalClearedLines = totalClearedLines
        self.combo = combo
        self.backToBack = backToBack
        self.lastAction = lastAction
        self.lastClearEvent = lastClearEvent
        self.gravityIntervalMilliseconds = gravityIntervalMilliseconds
        self.gravityAccumulatorMilliseconds = gravityAccumulatorMilliseconds
        self.lockController = lockController
    }

    public static func newGame(
        seed: UInt64,
        visibleNextCount: Int = 5,
        mode: GameMode = .marathon
    ) -> GameState {
        var nextQueue = NextQueue(
            randomizer: SevenBagRandomizer(seed: seed),
            visibleCount: visibleNextCount
        )
        let board = Board()
        let activeType = nextQueue.popNext()
        let activePiece = spawnPiece(type: activeType)
        let status: GameStatus = board.canPlace(activePiece) ? .playing : .gameOver

        return GameState(
            status: status,
            mode: mode,
            board: board,
            activePiece: activePiece,
            holdPiece: nil,
            holdUsed: false,
            nextQueue: nextQueue
        )
    }

    @discardableResult
    public mutating func hold() -> Bool {
        guard let activePiece, !holdUsed else {
            recordAction(type: .hold, succeeded: false)
            return false
        }

        let nextActiveType: PieceType
        if let heldType = holdPiece {
            nextActiveType = heldType
            holdPiece = activePiece.type
        } else {
            holdPiece = activePiece.type
            nextActiveType = nextQueue.popNext()
        }

        let spawned = Self.spawnPiece(type: nextActiveType)
        self.activePiece = spawned
        holdUsed = true
        lockController.resetForSpawn()
        lastAction = ActionRecord(type: .hold, pieceType: activePiece.type, succeeded: true)

        if !board.canPlace(spawned) {
            status = .gameOver
        }

        return true
    }

    @discardableResult
    public mutating func moveActivePiece(dx: Int, dy: Int) -> Bool {
        guard let activePiece else {
            recordAction(type: .move, succeeded: false)
            return false
        }

        let moved = activePiece.movedBy(dx: dx, dy: dy)
        guard board.canPlace(moved) else {
            lastAction = ActionRecord(type: .move, pieceType: activePiece.type, succeeded: false)
            return false
        }

        self.activePiece = moved
        if lockController.isGrounded {
            _ = lockController.recordSuccessfulAdjustment()
        }
        lastAction = ActionRecord(type: .move, pieceType: activePiece.type, succeeded: true)
        return true
    }

    @discardableResult
    public mutating func rotateActivePiece(_ direction: RotationDirection) -> Bool {
        guard let activePiece else {
            recordAction(type: .rotate, succeeded: false)
            return false
        }

        let isGrounded = !board.canPlace(activePiece.movedBy(dx: 0, dy: -1))
        guard let result = RotationSystem.srs.rotate(
            activePiece,
            direction: direction,
            on: board,
            isGrounded: isGrounded
        ) else {
            lastAction = ActionRecord(type: .rotate, pieceType: activePiece.type, succeeded: false)
            return false
        }

        self.activePiece = result.piece
        if lockController.isGrounded {
            _ = lockController.recordSuccessfulAdjustment()
        }
        lastAction = ActionRecord(
            type: .rotate,
            pieceType: activePiece.type,
            rotationFrom: activePiece.rotation,
            rotationTo: result.piece.rotation,
            kickIndex: result.kickIndex,
            succeeded: true
        )
        return true
    }

    @discardableResult
    public mutating func tick(deltaMilliseconds: Int) throws -> ClearEvent? {
        guard status == .playing, let activePiece else {
            return nil
        }

        if board.canPlace(activePiece.movedBy(dx: 0, dy: -1)) {
            lockController.resetForSpawn()
            gravityAccumulatorMilliseconds += max(deltaMilliseconds, 0)
            guard gravityAccumulatorMilliseconds >= gravityIntervalMilliseconds else {
                return nil
            }

            gravityAccumulatorMilliseconds -= gravityIntervalMilliseconds
            _ = moveActivePiece(dx: 0, dy: -1, actionType: .softDrop)
            return nil
        }

        switch lockController.update(canMoveDown: false, deltaMilliseconds: deltaMilliseconds) {
        case .wait:
            return nil
        case .lock:
            return try lockActivePiece()
        }
    }

    @discardableResult
    public mutating func hardDrop() throws -> ClearEvent {
        guard var piece = activePiece else {
            throw GameStateError.noActivePiece
        }

        var droppedCells = 0
        while board.canPlace(piece.movedBy(dx: 0, dy: -1)) {
            piece = piece.movedBy(dx: 0, dy: -1)
            droppedCells += 1
        }

        activePiece = piece
        lastAction = ActionRecord(type: .hardDrop, pieceType: piece.type, succeeded: true)
        return try lockActivePiece(hardDropCells: droppedCells)
    }

    @discardableResult
    public mutating func lockActivePiece(hardDropCells: Int = 0, softDropCells: Int = 0) throws -> ClearEvent {
        guard let piece = activePiece else {
            throw GameStateError.noActivePiece
        }
        guard board.canPlace(piece) else {
            throw GameStateError.invalidLockPosition
        }

        let spin = SpinDetector.detectSpin(board: board, piece: piece, lastAction: lastAction)
        try board.lock(piece)
        let fullLines = board.fullLines()
        let scoreResult = ScoringSystem.standard.score(
            ScoreInput(
                spin: spin,
                clearedLines: fullLines.count,
                hardDropCells: hardDropCells,
                softDropCells: softDropCells,
                previousCombo: combo,
                previousBackToBack: backToBack,
                level: level
            )
        )
        let clearedLines = board.clearFullLines()

        score += scoreResult.scoreDelta
        combo = scoreResult.nextCombo
        backToBack = scoreResult.nextBackToBack
        totalClearedLines += clearedLines.count
        level = totalClearedLines / 10 + 1

        let event = ClearEvent(
            clearedLines: clearedLines.count,
            spin: spin,
            clearName: scoreResult.clearName,
            scoreDelta: scoreResult.scoreDelta,
            attack: GarbageCalculator.standard.calculate(
                event: ClearEvent(
                    clearedLines: clearedLines.count,
                    spin: spin,
                    clearName: scoreResult.clearName,
                    scoreDelta: scoreResult.scoreDelta,
                    attack: 0,
                    combo: combo,
                    backToBack: backToBack,
                    backToBackBonusApplied: scoreResult.backToBackBonusApplied
                ),
                incomingGarbage: []
            ).outgoingAttack,
            combo: combo,
            backToBack: backToBack,
            backToBackBonusApplied: scoreResult.backToBackBonusApplied
        )
        lastClearEvent = event
        holdUsed = false
        lastAction = ActionRecord(type: .lock, pieceType: piece.type, succeeded: true)
        lockController.resetForSpawn()
        if mode == .fortyLines && totalClearedLines >= 40 {
            status = .completed
            activePiece = nil
        } else {
            spawnNextPiece()
        }

        return event
    }

    public static func spawnPiece(type: PieceType) -> Piece {
        Piece(type: type, origin: Cell(x: Board.visibleWidth / 2 - 1, y: Board.visibleHeight - 1), rotation: .north)
    }

    public mutating func setGravityIntervalMilliseconds(_ interval: Int) {
        gravityIntervalMilliseconds = max(interval, 1)
        gravityAccumulatorMilliseconds = min(gravityAccumulatorMilliseconds, gravityIntervalMilliseconds - 1)
    }

    private mutating func spawnNextPiece() {
        let nextType = nextQueue.popNext()
        let spawned = Self.spawnPiece(type: nextType)
        activePiece = spawned
        gravityAccumulatorMilliseconds = 0
        lockController.resetForSpawn()
        status = board.canPlace(spawned) ? .playing : .gameOver
    }

    @discardableResult
    private mutating func moveActivePiece(dx: Int, dy: Int, actionType: ActionType) -> Bool {
        guard let activePiece else {
            recordAction(type: actionType, succeeded: false)
            return false
        }

        let moved = activePiece.movedBy(dx: dx, dy: dy)
        guard board.canPlace(moved) else {
            lastAction = ActionRecord(type: actionType, pieceType: activePiece.type, succeeded: false)
            return false
        }

        self.activePiece = moved
        lastAction = ActionRecord(type: actionType, pieceType: activePiece.type, succeeded: true)
        return true
    }

    private mutating func recordAction(type: ActionType, succeeded: Bool) {
        let pieceType = activePiece?.type ?? holdPiece ?? .i
        lastAction = ActionRecord(type: type, pieceType: pieceType, succeeded: succeeded)
    }
}
