import Foundation

/// Deterministically builds a full-coverage puzzle on a folded cube surface.
public enum CubeLevelGenerator {
    static let candidateTarget = 10
    static let maximumAttempts = 128

    public static func generate(
        level: Int,
        track: LevelTrack,
        salt: UInt64 = 0
    ) -> CubeLevelBlueprint {
        let level = max(1, level)
        let parameters = CubeDifficultyCurve.parameters(level: level, track: track)
        let target = CubeDifficultyCurve.targetTwistiness(level: level, track: track)
        var best: CubeLevelBlueprint?
        var bestScore = Double.greatestFiniteMagnitude
        var found = 0

        for attempt in 0..<maximumAttempts {
            let attemptSeed = seed(level: level, track: track, salt: salt, attempt: attempt)
            guard let candidate = build(
                level: level,
                track: track,
                parameters: parameters,
                seed: attemptSeed
            ) else { continue }

            found += 1
            let score = quality(of: candidate, parameters: parameters, target: target)
            if score < bestScore {
                best = candidate
                bestScore = score
            }
            if found >= candidateTarget { break }
        }

        return best ?? fallback(level: level, track: track, parameters: parameters)
    }

    public static func seed(
        level: Int,
        track: LevelTrack,
        salt: UInt64,
        attempt: Int
    ) -> UInt64 {
        LevelGenerator.seed(level: level, track: track, salt: salt, attempt: attempt)
            ^ 0xC6BC_2796_92B5_C323
    }

    static func build(
        level: Int,
        track: LevelTrack,
        parameters: CubeLevelParameters,
        seed: UInt64
    ) -> CubeLevelBlueprint? {
        var rng = SeededRandom(seed: seed)
        let all = allCells(parameters: parameters)
        guard let blocked = pickBlocked(&rng, from: all, side: parameters.side,
                                        count: parameters.blocked) else { return nil }

        let cap = max(3, (parameters.playableCells * 3) / (2 * max(1, parameters.colors)))
        guard var paths = partition(
            &rng,
            cells: all.subtracting(blocked),
            side: parameters.side,
            maximumLength: cap
        ), let repaired = absorbSingletons(&rng, paths: paths, side: parameters.side)
        else { return nil }
        paths = repaired

        guard let retargeted = retargetColors(
            &rng,
            paths: paths,
            target: parameters.colors,
            side: parameters.side
        ) else { return nil }

        let blueprint = CubeLevelBlueprint(
            level: level,
            track: track,
            side: parameters.side,
            activeFaces: parameters.activeFaces,
            blocked: blocked,
            solution: retargeted,
            seed: seed
        )
        let minimumSeams = CubeDifficultyCurve.minimumSeamCrossings(parameters: parameters)
        guard blueprint.seamCrossings >= minimumSeams,
              CubeLevelValidator.isValid(blueprint)
        else { return nil }
        return blueprint
    }

    // MARK: - Surface graph

    static func allCells(parameters: CubeLevelParameters) -> Set<CubeCell> {
        var result: Set<CubeCell> = []
        result.reserveCapacity(parameters.cells)
        for face in parameters.activeFaces {
            for y in 0..<parameters.side {
                for x in 0..<parameters.side {
                    result.insert(CubeCell(face: face, x: x, y: y))
                }
            }
        }
        return result
    }

    static func neighbours(of cell: CubeCell, in cells: Set<CubeCell>, side: Int) -> [CubeCell] {
        cell.neighbours(side: side).filter { cells.contains($0) }
    }

    static func isConnected(_ cells: Set<CubeCell>, side: Int) -> Bool {
        guard let start = cells.min() else { return true }
        var seen: Set<CubeCell> = [start]
        var stack = [start]
        while let current = stack.popLast() {
            for next in neighbours(of: current, in: cells, side: side)
            where seen.insert(next).inserted {
                stack.append(next)
            }
        }
        return seen.count == cells.count
    }

    static func pickBlocked(
        _ rng: inout SeededRandom,
        from all: Set<CubeCell>,
        side: Int,
        count: Int
    ) -> Set<CubeCell>? {
        guard count > 0 else { return [] }
        var blocked: Set<CubeCell> = []
        for candidate in rng.shuffled(all.sorted()) {
            if blocked.count == count { break }
            var trial = blocked
            trial.insert(candidate)
            let remaining = all.subtracting(trial)
            guard remaining.count >= 8, isConnected(remaining, side: side) else { continue }
            blocked = trial
        }
        return blocked.count == count ? blocked : nil
    }

    // MARK: - Partition and repair

    static func partition(
        _ rng: inout SeededRandom,
        cells: Set<CubeCell>,
        side: Int,
        maximumLength: Int
    ) -> [[CubeCell]]? {
        var free = cells
        var paths: [[CubeCell]] = []
        var guardCounter = 0

        func freeNeighbourCount(_ cell: CubeCell) -> Int {
            cell.neighbours(side: side).reduce(into: 0) { count, neighbour in
                if free.contains(neighbour) { count += 1 }
            }
        }

        while !free.isEmpty {
            guardCounter += 1
            if guardCounter > cells.count + 8 { return nil }
            let ordered = rng.shuffled(free.sorted())
            guard let start = ordered.min(by: {
                freeNeighbourCount($0) < freeNeighbourCount($1)
            }) else { return nil }
            free.remove(start)

            var path = [start]
            for growAtTail in [true, false] {
                while path.count < maximumLength {
                    let head = growAtTail ? path[path.count - 1] : path[0]
                    let options = head.neighbours(side: side).filter { free.contains($0) }
                    guard !options.isEmpty else { break }
                    let step: CubeCell
                    if rng.chance(75) {
                        step = options.min {
                            freeNeighbourCount($0) < freeNeighbourCount($1)
                        }!
                    } else {
                        let shuffled = rng.shuffled(options)
                        step = rng.element(of: shuffled)!
                    }
                    free.remove(step)
                    if growAtTail { path.append(step) } else { path.insert(step, at: 0) }
                }
            }
            paths.append(path)
        }
        return paths
    }

    static func absorbSingletons(
        _ rng: inout SeededRandom,
        paths: [[CubeCell]],
        side: Int
    ) -> [[CubeCell]]? {
        var paths = paths
        for _ in 0..<512 {
            guard let index = paths.firstIndex(where: { $0.count == 1 }) else { return paths }
            let cell = paths[index][0]
            var owner: [CubeCell: (path: Int, offset: Int)] = [:]
            for (pathIndex, path) in paths.enumerated() {
                for (offset, tile) in path.enumerated() {
                    owner[tile] = (pathIndex, offset)
                }
            }

            let options = cell.neighbours(side: side).filter {
                owner[$0].map { $0.path != index } ?? false
            }
            guard !options.isEmpty else { return nil }
            let endpoints = options.filter { candidate in
                guard let entry = owner[candidate] else { return false }
                return entry.offset == 0 || entry.offset == paths[entry.path].count - 1
            }
            let pool = rng.shuffled(endpoints.isEmpty ? options : endpoints)
            guard let target = rng.element(of: pool), let entry = owner[target] else { return nil }
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

    static func join(_ first: [CubeCell], _ second: [CubeCell], side: Int) -> [CubeCell]? {
        if CubeTopology.areAdjacent(first.last!, second.first!, side: side) {
            return first + second
        }
        if CubeTopology.areAdjacent(first.last!, second.last!, side: side) {
            return first + second.reversed()
        }
        if CubeTopology.areAdjacent(first.first!, second.first!, side: side) {
            return first.reversed() + second
        }
        if CubeTopology.areAdjacent(first.first!, second.last!, side: side) {
            return second + first
        }
        return nil
    }

    @discardableResult
    static func mergeShortest(_ paths: inout [[CubeCell]], side: Int) -> Bool {
        var best: (i: Int, j: Int, joined: [CubeCell])?
        for i in 0..<paths.count {
            for j in (i + 1)..<paths.count {
                guard let joined = join(paths[i], paths[j], side: side) else { continue }
                if let current = best, joined.count >= current.joined.count { continue }
                best = (i, j, joined)
            }
        }
        guard let best else { return false }
        paths[best.i] = best.joined
        paths.remove(at: best.j)
        return true
    }

    @discardableResult
    static func splitLongest(
        _ rng: inout SeededRandom,
        _ paths: inout [[CubeCell]]
    ) -> Bool {
        guard let index = paths.indices
            .filter({ paths[$0].count >= 4 })
            .max(by: { paths[$0].count < paths[$1].count })
        else { return false }
        let path = paths[index]
        let cut = min(max(2, path.count / 2 + rng.int(below: 3) - 1), path.count - 2)
        paths[index] = Array(path[0..<cut])
        paths.append(Array(path[cut...]))
        return true
    }

    static func retargetColors(
        _ rng: inout SeededRandom,
        paths: [[CubeCell]],
        target: Int,
        side: Int
    ) -> [[CubeCell]]? {
        var paths = paths
        var guardCounter = 0
        while paths.count > target {
            guardCounter += 1
            if guardCounter > 768 || !mergeShortest(&paths, side: side) { return nil }
        }
        while paths.count < target {
            guardCounter += 1
            if guardCounter > 768 || !splitLongest(&rng, &paths) { return nil }
        }

        for _ in 0..<24 {
            guard let longest = paths.map(\.count).max(),
                  let shortest = paths.map(\.count).min(),
                  longest > max(4, shortest * 3)
            else { break }
            let snapshot = paths
            if !splitLongest(&rng, &paths) || !mergeShortest(&paths, side: side)
                || paths.count != target || (paths.map(\.count).max() ?? 0) >= longest {
                paths = snapshot
                break
            }
        }
        return paths.allSatisfy { $0.count >= 2 } ? paths : nil
    }

    // MARK: - Selection and fallback

    static func quality(
        of blueprint: CubeLevelBlueprint,
        parameters: CubeLevelParameters,
        target: Double
    ) -> Double {
        let turnRatio = Double(blueprint.turnCount) / Double(max(1, parameters.playableCells))
        var score = abs(turnRatio - target) * 4
        let seamTarget = CubeDifficultyCurve.minimumSeamCrossings(parameters: parameters) + 2
        score += Double(max(0, seamTarget - blueprint.seamCrossings)) * 0.18
        let lengths = blueprint.solution.map(\.count)
        let average = Double(parameters.playableCells) / Double(max(1, lengths.count))
        score += max(0, Double(lengths.max() ?? 0) / average - 1.8) * 0.9
        return score
    }

    /// Guaranteed path made by joining one Hamiltonian snake per active face.
    static func fallback(
        level: Int,
        track: LevelTrack,
        parameters: CubeLevelParameters
    ) -> CubeLevelBlueprint {
        let order = fallbackFaceOrder(parameters.activeFaces)
        let variants = Dictionary(uniqueKeysWithValues: order.map {
            ($0, faceSnakes(face: $0, side: parameters.side))
        })

        func assemble(_ faceIndex: Int, _ current: [CubeCell]) -> [CubeCell]? {
            if faceIndex == order.count { return current }
            for candidate in variants[order[faceIndex]] ?? [] {
                if current.isEmpty || CubeTopology.areAdjacent(
                    current.last!, candidate.first!, side: parameters.side
                ) {
                    if let result = assemble(faceIndex + 1, current + candidate) { return result }
                }
            }
            return nil
        }

        let snake = assemble(0, []) ?? order.flatMap {
            faceSnakes(face: $0, side: parameters.side)[0]
        }
        let paths = splitFallbackSnake(snake, colors: parameters.colors)
        let blueprint = CubeLevelBlueprint(
            level: level,
            track: track,
            side: parameters.side,
            activeFaces: parameters.activeFaces,
            blocked: [],
            solution: paths,
            seed: 0
        )
        precondition(CubeLevelValidator.isValid(blueprint), "invalid cube fallback")
        return blueprint
    }

    static func fallbackFaceOrder(_ active: [CubeFace]) -> [CubeFace] {
        switch active.count {
        case 1: return [.front]
        case 2: return [.front, .right]
        case 3: return [.front, .right, .back]
        case 4: return [.front, .right, .back, .left]
        case 5: return [.front, .right, .back, .left, .top]
        default: return [.front, .right, .bottom, .back, .left, .top]
        }
    }

    static func faceSnakes(face: CubeFace, side: Int) -> [[CubeCell]] {
        var base: [(Int, Int)] = []
        for y in 0..<side {
            let columns = y.isMultiple(of: 2)
                ? Array(0..<side)
                : Array((0..<side).reversed())
            for x in columns { base.append((x, y)) }
        }

        let transforms: [((Int, Int)) -> (Int, Int)] = [
            { ($0.0, $0.1) },
            { (side - 1 - $0.1, $0.0) },
            { (side - 1 - $0.0, side - 1 - $0.1) },
            { ($0.1, side - 1 - $0.0) },
            { (side - 1 - $0.0, $0.1) },
            { (side - 1 - $0.1, side - 1 - $0.0) },
            { ($0.0, side - 1 - $0.1) },
            { ($0.1, $0.0) },
        ]
        var unique: [[CubeCell]] = []
        for transform in transforms {
            let path = base.map { point -> CubeCell in
                let transformed = transform(point)
                return CubeCell(face: face, x: transformed.0, y: transformed.1)
            }
            for value in [path, Array(path.reversed())] {
                if !unique.contains(value) { unique.append(value) }
            }
        }
        return unique
    }

    static func splitFallbackSnake(_ snake: [CubeCell], colors: Int) -> [[CubeCell]] {
        var paths: [[CubeCell]] = []
        var cursor = 0
        let seamCuts = Set((1..<snake.count).filter { snake[$0 - 1].face != snake[$0].face })

        for index in 0..<colors {
            let remainingColors = colors - index - 1
            if remainingColors == 0 {
                paths.append(Array(snake[cursor...]))
                break
            }
            let remainingCells = snake.count - cursor
            let desired = cursor + max(2, remainingCells / (remainingColors + 1))
            let maximum = snake.count - remainingColors * 2
            var cut = min(desired, maximum)
            while seamCuts.contains(cut), cut < maximum { cut += 1 }
            while seamCuts.contains(cut), cut > cursor + 2 { cut -= 1 }
            paths.append(Array(snake[cursor..<cut]))
            cursor = cut
        }
        return paths
    }
}
