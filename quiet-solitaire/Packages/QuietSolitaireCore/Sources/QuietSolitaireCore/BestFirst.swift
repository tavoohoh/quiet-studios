/// Best-first search over the same positions and steps as `Solver`'s depth-first search:
/// it always expands the most promising position seen so far (more cards home, fewer
/// face down), so one huge bad branch can't eat the whole budget. Ties go to the earliest
/// position, so the result is the same on every device.
struct BestFirstSearch {
    let budget: Int
    let complete: Bool
    private(set) var expanded = 0
    private(set) var exhausted = false

    private struct Node {
        let parent: Int
        let step: Step?
        let depth: Int
    }

    init(budget: Int, complete: Bool) {
        self.budget = budget
        self.complete = complete
    }

    /// Higher is better.
    static func score(_ p: Position, depth: Int) -> Int {
        let home = p.foundations.reduce(0, +)
        let faceDown = p.down.reduce(0) { $0 + $1.count }
        let empty = (0..<7).filter { p.up[$0].isEmpty && p.down[$0].isEmpty }.count
        return home * 10 - faceDown * 14 - p.talon.count * 2 + empty * 3 - depth
    }

    mutating func run(_ start: Position) -> [Step]? {
        var nodes = [Node(parent: -1, step: nil, depth: 0)]
        var heap = Heap()
        var positions: [Int: Position] = [0: start]
        var seen: Set<UInt64> = [start.key]
        heap.push(score: Self.score(start, depth: 0), id: 0)
        while let id = heap.pop() {
            guard let position = positions.removeValue(forKey: id) else { continue }
            if position.isWon { return path(to: id, nodes) }
            guard expanded < budget else { exhausted = true; return nil }
            expanded += 1
            let depth = nodes[id].depth + 1
            for step in position.steps(complete: complete) {
                let next = position.applying(step)
                guard seen.insert(next.key).inserted else { continue }
                let childID = nodes.count
                nodes.append(Node(parent: id, step: step, depth: depth))
                if next.isWon { return path(to: childID, nodes) }
                positions[childID] = next
                heap.push(score: Self.score(next, depth: depth), id: childID)
            }
        }
        return nil
    }

    private func path(to id: Int, _ nodes: [Node]) -> [Step] {
        var steps: [Step] = []
        var current = id
        while current > 0, let step = nodes[current].step {
            steps.append(step)
            current = nodes[current].parent
        }
        return steps.reversed()
    }
}

/// Max-heap of (score, id); equal scores pop the lower id first.
private struct Heap {
    private var items: [(score: Int, id: Int)] = []

    private func before(_ a: (score: Int, id: Int), _ b: (score: Int, id: Int)) -> Bool {
        a.score != b.score ? a.score > b.score : a.id < b.id
    }

    mutating func push(score: Int, id: Int) {
        items.append((score, id))
        var i = items.count - 1
        while i > 0 {
            let parent = (i - 1) / 2
            guard before(items[i], items[parent]) else { break }
            items.swapAt(i, parent)
            i = parent
        }
    }

    mutating func pop() -> Int? {
        guard !items.isEmpty else { return nil }
        let top = items[0].id
        let last = items.removeLast()
        if !items.isEmpty {
            items[0] = last
            var i = 0
            while true {
                let l = 2 * i + 1, r = l + 1
                var best = i
                if l < items.count, before(items[l], items[best]) { best = l }
                if r < items.count, before(items[r], items[best]) { best = r }
                if best == i { break }
                items.swapAt(i, best)
                i = best
            }
        }
        return top
    }
}
