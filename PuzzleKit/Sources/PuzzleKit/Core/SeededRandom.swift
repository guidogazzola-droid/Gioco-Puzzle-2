import Foundation

/// Deterministic pseudo-random generator (SplitMix64).
///
/// Every level in Fieldweave is generated on device from a seed derived from
/// the level number, so the same level looks identical on every device and in
/// every future build without shipping a single level file. That only works if
/// the generator is bit-for-bit reproducible, which `Foundation.random` is not.
///
/// The algorithm is mirrored by `tools/generator_reference.py`, the harness the
/// generation rules are validated against.
public struct SeededRandom: RandomNumberGenerator, Sendable {

    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform value in `0..<bound` with the modulo bias rejected.
    public mutating func int(below bound: Int) -> Int {
        guard bound > 1 else { return 0 }
        let limit = UInt64(bound)
        // (2^64 - limit) % limit == 2^64 % limit: values below it would skew.
        let threshold = (0 &- limit) % limit
        while true {
            let candidate = next()
            if candidate >= threshold {
                return Int(candidate % limit)
            }
        }
    }

    /// Uniform value in `range`.
    public mutating func int(in range: ClosedRange<Int>) -> Int {
        range.lowerBound + int(below: range.count)
    }

    public mutating func element<T>(of items: [T]) -> T? {
        items.isEmpty ? nil : items[int(below: items.count)]
    }

    public mutating func shuffled<T>(_ items: [T]) -> [T] {
        var result = items
        var index = result.count - 1
        while index > 0 {
            result.swapAt(index, int(below: index + 1))
            index -= 1
        }
        return result
    }

    /// `true` with the given probability, expressed in percent.
    public mutating func chance(_ percent: Int) -> Bool {
        int(below: 100) < percent
    }
}

public extension SeededRandom {
    /// Stable 64-bit hash of a string, used to seed date-based content such as
    /// the daily challenge. `Hasher` is deliberately unstable across launches,
    /// so it cannot be used here.
    static func hash(_ value: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325          // FNV-1a offset basis
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3          // FNV prime
        }
        return hash
    }
}
