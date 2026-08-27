import Foundation

/// Builds guaranteed-solvable Prism Flow boards from nothing but a level number.
///
/// The board is produced by *construction*, never by search: the generator first
/// partitions every playable cell into vertex-disjoint simple paths, then hands
/// the player only the two ends of each path. Because the partition already
/// covers the board, a full-coverage solution provably exists - the generator
/// just built one. That removes the classic procedural-puzzle failure mode of
/// shipping an unsolvable level, and it is why no solver is needed at runtime.
///
/// The algorithm is validated end to end by `tools/generator_reference.py`,
/// which is a line-for-line twin of this file.
public enum LevelGenerator {

    /// How many valid boards to build before picking the nicest one.
    static let candidateTarget = 12
    /// Hard ceiling on attempts, so a pathological seed can never spin.
    static let maximumAttempts = 96

    // MARK: - Public API

    /// Generates the board for `level` on `track`.
    ///
    /// Deterministic: the same `(level, track, salt)` always returns the same
    /// board, on every device and in every build.
    /// - Parameter salt: extra entropy for non-numbered content such as the
    ///   daily challenge. Leave at `0` for campaign levels.
    public static func generate(level: Int, track: LevelTrack, salt: UInt64 = 0) -> LevelBlueprint {
        let level = max(1, level)
        let parameters = DifficultyCurve.parameters(level: level, track: track)
        let target = DifficultyCurve.targetTwistiness(level: level, track: track)

        var best: LevelBlueprint?
        var bestScore = Double.greatestFiniteMagnitude
        var found = 0

        for attempt in 0..<maximumAttempts {
            let seed = seed(level: level, track: track, salt: salt, attempt: attempt)
            guard let candidate = build(level: level, track: track, parameters: parameters, seed: seed) else {
                continue
            }
            found += 1
            let score = quality(of: candidate, parameters: parameters, target: target)
            if score < bestScore {
                best = candidate
                bestScore = score
            }
            if found >= candidateTarget { break }
        }

        // Unreachable in practice - 800 levels across both tracks are verified
        // in tests - but a puzzle game must never fail to produce a board.
        return best ?? fallback(level: level, track: track, parameters: parameters)
    }

    /// The seed for one generation attempt.
    public static func seed(level: Int, track: LevelTrack, salt: UInt64, attempt: Int) -> UInt64 {
        UInt64(bitPattern: Int64(level)) &* 0x9E37_79B9_7F4A_7C15
            &+ track.seedSalt
            &+ salt &* 0x0100_0001
            &+ UInt64(attempt) &* 0x2545_F491
    }

    // MARK: - One attempt

    static func build(
        level: Int,
        track: LevelTrack,
        parameters: LevelParameters,
        seed: UInt64
    ) -> LevelBlueprint? {
        var rng = SeededRandom(seed: seed)

        guard let blocked = pickBlocked(
            &rng,
            width: parameters.width,
            height: parameters.height,
            count: parameters.blocked
        ) else { return nil }

        // Cap path length at 1.5x the average so no single colour can swallow
        // the board - unbalanced colour lengths are what make a Flow board
        // unreadable.
        let cap = max(3, (parameters.playableCells * 3) / (2 * max(1, parameters.colors)))

        guard var paths = partition(
            &rng,
            width: parameters.width,
            height: parameters.height,
            blocked: blocked,
            maximumLength: cap
        ) else { return nil }

        guard let absorbed = absorbSingletons(
            &rng,
            paths: paths,
            width: parameters.width,
            height: parameters.height
        ) else { return nil }
        paths = absorbed

        guard let retargeted = retargetColors(&rng, paths: paths, target: parameters.colors) else {
            return nil
        }
        paths = retargeted

        guard paths.allSatisfy({ $0.count >= 2 }) else { return nil }

        let blueprint = LevelBlueprint(
            level: level,
            track: track,
            width: parameters.width,
            height: parameters.height,
            blocked: blocked,
            solution: paths,
            seed: seed
        )
        return LevelValidator.isValid(blueprint) ? blueprint : nil
    }

    // MARK: - Walls

    /// Picks wall cells one at a time, keeping the remaining board orthogonally
    /// connected - an island of free cells would be unsolvable.
    static func pickBlocked(
        _ rng: inout SeededRandom,
        width: Int,
        height: Int,
        count: Int
    ) -> Set<Coordinate>? {
        guard count > 0 else { return [] }
        var allCells: [Coordinate] = []
        allCells.reserveCapacity(width * height)
        for y in 0..<height {
            for x in 0..<width { allCells.append(Coordinate(x, y)) }
        }

        let everyCell = Set(allCells)
        var blocked: Set<Coordinate> = []
        for candidate in rng.shuffled(allCells) {
            if blocked.count == count { break }
            var trial = blocked
            trial.insert(candidate)
            let remaining = everyCell.subtracting(trial)
            guard remaining.count >= 6 else { continue }
            if isConnected(remaining, width: width, height: height) {
                blocked = trial
            }
        }
        return blocked.count == count ? blocked : nil
    }

    static func isConnected(_ cells: Set<Coordinate>, width: Int, height: Int) -> Bool {
        guard let start = cells.min() else { return true }
        var seen: Set<Coordinate> = [start]
        var stack: [Coordinate] = [start]
        while let current = stack.popLast() {
            for neighbour in current.neighbours(width: width, height: height)
            where cells.contains(neighbour) && !seen.contains(neighbour) {
                seen.insert(neighbour)
                stack.append(neighbour)
            }
        }
        return seen.count == cells.count
    }

    // MARK: - Partition

    /// Covers every free cell with vertex-disjoint simple paths.
    ///
    /// Paths grow from both ends with a Warnsdorff-style bias - step onto the
    /// neighbour with the fewest onward options - which is what stops the board
    /// fragmenting into stranded single cells.
    static func partition(
        _ rng: inout SeededRandom,
        width: Int,
        height: Int,
        blocked: Set<Coordinate>,
        maximumLength: Int
    ) -> [[Coordinate]]? {
        var free: Set<Coordinate> = []
        for y in 0..<height {
            for x in 0..<width {
                let cell = Coordinate(x, y)
                if !blocked.contains(cell) { free.insert(cell) }
            }
        }

        func freeNeighbourCount(_ cell: Coordinate) -> Int {
            cell.neighbours(width: width, height: height).reduce(into: 0) { count, neighbour in
                if free.contains(neighbour) { count += 1 }
            }
        }

        var paths: [[Coordinate]] = []
        var guardCounter = 0

        while !free.isEmpty {
            guardCounter += 1
            if guardCounter > width * height + 8 { return nil }

            // Start from the most constrained free cell, random among ties.
            let ordered = rng.shuffled(free.sorted())
            guard let start = ordered.min(by: { freeNeighbourCount($0) < freeNeighbourCount($1) })
            else { return nil }
            free.remove(start)

            var path: [Coordinate] = [start]
            for growingFromTail in [true, false] {
                while path.count < maximumLength {
                    let head = growingFromTail ? path[path.count - 1] : path[0]
                    let options = head.neighbours(width: width, height: height)
                        .filter { free.contains($0) }
                    guard !options.isEmpty else { break }

                    let step: Coordinate
                    if rng.chance(75) {
                        step = options.min(by: { freeNeighbourCount($0) < freeNeighbourCount($1) })!
                    } else {
                        let pool = rng.shuffled(options)
                        step = rng.element(of: pool)!
                    }
                    free.remove(step)
                    if growingFromTail {
                        path.append(step)
                    } else {
                        path.insert(step, at: 0)
                    }
                }
            }
            paths.append(path)
        }
        return paths
    }

    // MARK: - Singleton repair

    /// Removes every length-1 path by grafting it onto a neighbouring path.
    ///
    /// Grafting onto an endpoint merges two paths; grafting mid-path splits the
    /// host instead. Both keep the covering valid, so a singleton is always
    /// repairable as long as it has any neighbour at all.
    static func absorbSingletons(
        _ rng: inout SeededRandom,
        paths: [[Coordinate]],
        width: Int,
        height: Int
    ) -> [[Coordinate]]? {
        var paths = paths
        for _ in 0..<256 {
            guard let index = paths.firstIndex(where: { $0.count == 1 }) else { return paths }
            let cell = paths[index][0]

            var owner: [Coordinate: (path: Int, offset: Int)] = [:]
            for (pathIndex, path) in paths.enumerated() {
                for (offset, coordinate) in path.enumerated() {
                    owner[coordinate] = (pathIndex, offset)
                }
            }

            let options = cell.neighbours(width: width, height: height).filter {
                if let entry = owner[$0] { return entry.path != index }
                return false
            }
            guard !options.isEmpty else { return nil }

            // Prefer an endpoint: that merges two paths instead of making a third.
            let endpointOptions = options.filter { candidate in
                guard let entry = owner[candidate] else { return false }
                return entry.offset == 0 || entry.offset == paths[entry.path].count - 1
            }
            let pool = rng.shuffled(endpointOptions.isEmpty ? options : endpointOptions)
            guard let target = rng.element(of: pool), let entry = owner[target] else {
                return nil
            }

            let host = paths[entry.path]
            if entry.offset == 0 {
                paths[entry.path] = [cell] + host
                paths.remove(at: index)
            } else if entry.offset == host.count - 1 {
                paths[entry.path] = host + [cell]
                paths.remove(at: index)
            } else {
                paths[entry.path] = Array(host[0..<entry.offset])
                paths.append(Array(host[(entry.offset + 1)...]))
                paths[index] = [target, cell]
            }
        }
        return nil
    }

    // MARK: - Colour count

    /// Concatenates two vertex-disjoint simple paths whose endpoints touch.
    /// The result is always itself a simple path.
    static func join(_ a: [Coordinate], _ b: [Coordinate]) -> [Coordinate]? {
        if a[a.count - 1].isAdjacent(to: b[0]) { return a + b }
        if a[a.count - 1].isAdjacent(to: b[b.count - 1]) { return a + b.reversed() }
        if a[0].isAdjacent(to: b[0]) { return a.reversed() + b }
        if a[0].isAdjacent(to: b[b.count - 1]) { return b + a }
        return nil
    }

    /// Merges the cheapest mergeable pair - shortest combined length wins, so
    /// colour lengths stay even. Ties break on index order, keeping it
    /// deterministic. Returns `false` when nothing can be merged.
    @discardableResult
    static func mergeShortest(_ paths: inout [[Coordinate]]) -> Bool {
        var best: (i: Int, j: Int, joined: [Coordinate])?
        for i in 0..<paths.count {
            for j in (i + 1)..<paths.count {
                guard let joined = join(paths[i], paths[j]) else { continue }
                if let current = best, joined.count >= current.joined.count { continue }
                best = (i, j, joined)
            }
        }
        guard let winner = best else { return false }
        paths[winner.i] = winner.joined
        paths.remove(at: winner.j)
        return true
    }

    /// Splits the longest path near its middle, keeping both halves >= 2 cells.
    @discardableResult
    static func splitLongest(_ rng: inout SeededRandom, _ paths: inout [[Coordinate]]) -> Bool {
        var longest: (index: Int, length: Int)?
        for (index, path) in paths.enumerated() where path.count >= 4 {
            if let current = longest, path.count <= current.length { continue }
            longest = (index, path.count)
        }
        guard let index = longest?.index else { return false }

        let path = paths[index]
        let jitter = rng.int(below: 3) - 1
        let cut = min(max(2, path.count / 2 + jitter), path.count - 2)
        paths[index] = Array(path[0..<cut])
        paths.append(Array(path[cut...]))
        return true
    }

    /// Merges or splits until exactly `target` paths remain, then evens out the
    /// lengths without changing the count.
    static func retargetColors(
        _ rng: inout SeededRandom,
        paths: [[Coordinate]],
        target: Int
    ) -> [[Coordinate]]? {
        var paths = paths
        var guardCounter = 0

        while paths.count > target {
            guardCounter += 1
            if guardCounter > 512 || !mergeShortest(&paths) { return nil }
        }
        while paths.count < target {
            guardCounter += 1
            if guardCounter > 512 || !splitLongest(&rng, &paths) { return nil }
        }

        // Rebalance at a fixed colour count: split the hog, re-absorb the runt.
        for _ in 0..<24 {
            guard let longest = paths.map(\.count).max(),
                  let shortest = paths.map(\.count).min() else { break }
            if longest <= max(4, shortest * 3) { break }

            let snapshot = paths
            if !splitLongest(&rng, &paths) || !mergeShortest(&paths) {
                paths = snapshot
                break
            }
            if paths.count != target || (paths.map(\.count).max() ?? 0) >= longest {
                paths = snapshot
                break
            }
        }
        return paths.allSatisfy { $0.count >= 2 } ? paths : nil
    }

    // MARK: - Candidate scoring

    /// Lower is better: how close a candidate board is to the intended feel.
    static func quality(
        of blueprint: LevelBlueprint,
        parameters: LevelParameters,
        target: Double
    ) -> Double {
        let ratio = Double(blueprint.turnCount) / Double(max(1, parameters.playableCells))
        var score = abs(ratio - target) * 4.0

        // Too many two-cell colours makes a board read as filler.
        let trivial = blueprint.solution.filter { $0.count <= 2 }.count
        let allowance = max(1, blueprint.colorCount / 3)
        if trivial > allowance { score += 0.35 * Double(trivial - allowance) }

        // One colour swallowing the board is the worst failure mode of all.
        let lengths = blueprint.solution.map(\.count)
        let average = Double(parameters.playableCells) / Double(max(1, lengths.count))
        score += max(0.0, (Double(lengths.max() ?? 0) / average) - 1.8) * 0.9
        return score
    }

    // MARK: - Fallback

    /// A trivially correct board, used only if every seeded attempt somehow
    /// failed: a serpentine sweep of the whole board cut into equal segments.
    /// A boustrophedon sweep visits every cell exactly once and each step is
    /// orthogonal, so any contiguous cut of it is a valid covering.
    static func fallback(level: Int, track: LevelTrack, parameters: LevelParameters) -> LevelBlueprint {
        var snake: [Coordinate] = []
        for y in 0..<parameters.height {
            let columns = y % 2 == 0
                ? Array(0..<parameters.width)
                : Array((0..<parameters.width).reversed())
            for x in columns { snake.append(Coordinate(x, y)) }
        }

        let colors = max(1, min(parameters.colors, snake.count / 2))
        var paths: [[Coordinate]] = []
        var cursor = 0
        for index in 0..<colors {
            let remaining = colors - index - 1
            let length = index == colors - 1
                ? snake.count - cursor
                : max(2, min(snake.count / colors, snake.count - cursor - remaining * 2))
            paths.append(Array(snake[cursor..<(cursor + length)]))
            cursor += length
        }

        return LevelBlueprint(
            level: level,
            track: track,
            width: parameters.width,
            height: parameters.height,
            blocked: [],
            solution: paths,
            seed: 0
        )
    }
}
