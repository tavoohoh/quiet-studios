/// Deterministic PRNG (SplitMix64). Same seed, same sequence, on every platform.
///
/// Bounded values are derived with our own rejection sampling instead of
/// `Int.random(in:using:)`, so the output never depends on stdlib internals.
public struct SeededRandom: RandomNumberGenerator, Codable, Hashable, Sendable {
    public private(set) var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform integer in `range`, unbiased.
    public mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound) + 1
        let limit = UInt64.max - (UInt64.max % span)
        var value = next()
        while value >= limit {
            value = next()
        }
        return range.lowerBound + Int(value % span)
    }
}

/// Stable 64-bit FNV-1a hash. Unlike `Hasher`, it is not randomized per process.
public enum FNV1a {
    public static func hash(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }
}
