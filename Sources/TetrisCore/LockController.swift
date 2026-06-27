public struct LockSettings: Equatable, Sendable {
    public let lockDelayMilliseconds: Int
    public let maxResets: Int

    public init(lockDelayMilliseconds: Int = 500, maxResets: Int = 15) {
        self.lockDelayMilliseconds = lockDelayMilliseconds
        self.maxResets = maxResets
    }
}

public enum LockDecision: Equatable, Sendable {
    case wait
    case lock
}

public struct LockController: Equatable, Sendable {
    public let settings: LockSettings
    public private(set) var isGrounded: Bool
    public private(set) var elapsedMilliseconds: Int
    public private(set) var resetCount: Int

    public init(
        settings: LockSettings = LockSettings(),
        isGrounded: Bool = false,
        elapsedMilliseconds: Int = 0,
        resetCount: Int = 0
    ) {
        self.settings = settings
        self.isGrounded = isGrounded
        self.elapsedMilliseconds = elapsedMilliseconds
        self.resetCount = resetCount
    }

    public mutating func update(canMoveDown: Bool, deltaMilliseconds: Int) -> LockDecision {
        if canMoveDown {
            clearGroundedState()
            return .wait
        }

        isGrounded = true
        elapsedMilliseconds += max(deltaMilliseconds, 0)

        if resetCount >= settings.maxResets || elapsedMilliseconds >= settings.lockDelayMilliseconds {
            return .lock
        }

        return .wait
    }

    @discardableResult
    public mutating func recordSuccessfulAdjustment() -> Bool {
        guard isGrounded, resetCount < settings.maxResets else {
            return false
        }

        elapsedMilliseconds = 0
        resetCount += 1
        return true
    }

    public mutating func forceLock() -> LockDecision {
        .lock
    }

    public mutating func resetForSpawn() {
        clearGroundedState()
    }

    private mutating func clearGroundedState() {
        isGrounded = false
        elapsedMilliseconds = 0
        resetCount = 0
    }
}
