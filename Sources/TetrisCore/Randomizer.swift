public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

public struct SevenBagRandomizer: Sendable {
    private var generator: SeededGenerator
    private var bag: [PieceType] = []

    public init(seed: UInt64) {
        generator = SeededGenerator(seed: seed)
    }

    public mutating func next() -> PieceType {
        if bag.isEmpty {
            bag = PieceType.allCases.shuffled(using: &generator)
        }
        return bag.removeFirst()
    }
}

public struct NextQueue: Sendable {
    public private(set) var randomizer: SevenBagRandomizer
    public let visibleCount: Int
    private var queue: [PieceType] = []

    public init(randomizer: SevenBagRandomizer, visibleCount: Int, prefill: Bool = true) {
        self.randomizer = randomizer
        self.visibleCount = visibleCount
        if prefill {
            refill()
        }
    }

    public var preview: [PieceType] {
        Array(queue.prefix(visibleCount))
    }

    public mutating func popNext() -> PieceType {
        let next = queue.removeFirst()
        refill()
        return next
    }

    private mutating func refill() {
        while queue.count < visibleCount + 1 {
            queue.append(randomizer.next())
        }
    }
}
