import Foundation
import Observation
import UIKit

enum Difficulty: CaseIterable, Identifiable {
    case beginner, intermediate, expert

    var id: Self { self }

    // 直式手機畫面：高級改為 16 欄 × 30 列
    var cols: Int { self == .beginner ? 9 : 16 }
    var rows: Int {
        switch self {
        case .beginner: 9
        case .intermediate: 16
        case .expert: 30
        }
    }
    var mines: Int {
        switch self {
        case .beginner: 10
        case .intermediate: 40
        case .expert: 99
        }
    }
    var label: String {
        switch self {
        case .beginner: "初級"
        case .intermediate: "中級"
        case .expert: "高級"
        }
    }
}

struct Cell {
    var mine = false
    var revealed = false
    var flagged = false
    var exploded = false
    var adjacent = 0
}

@MainActor
@Observable
final class Game {
    enum State { case ready, playing, won, lost }

    private(set) var difficulty: Difficulty
    private(set) var cells: [Cell] = []
    private(set) var state: State = .ready
    private(set) var elapsed = 0
    var flagMode = false

    private var timerTask: Task<Void, Never>?

    init(difficulty: Difficulty = .intermediate) {
        self.difficulty = difficulty
        reset()
    }

    var rows: Int { difficulty.rows }
    var cols: Int { difficulty.cols }
    var minesLeft: Int { difficulty.mines - cells.filter(\.flagged).count }
    var isOver: Bool { state == .won || state == .lost }

    func reset(_ newDifficulty: Difficulty? = nil) {
        if let newDifficulty { difficulty = newDifficulty }
        timerTask?.cancel()
        timerTask = nil
        cells = Array(repeating: Cell(), count: rows * cols)
        state = .ready
        elapsed = 0
    }

    func tap(_ i: Int) {
        guard cells.indices.contains(i) else { return }
        if flagMode && !cells[i].revealed {
            toggleFlag(i)
        } else {
            reveal(i)
        }
    }

    func toggleFlag(_ i: Int) {
        guard cells.indices.contains(i), !isOver, !cells[i].revealed else { return }
        cells[i].flagged.toggle()
        SoundPlayer.shared.play(.flag)
    }

    func reveal(_ i: Int) {
        guard !isOver, !cells[i].flagged else { return }

        if cells[i].revealed {
            chord(i)
            return
        }

        if state == .ready {
            placeMines(safe: i)
            state = .playing
            startTimer()
        }

        if cells[i].mine {
            lose(exploded: i)
            return
        }
        flood(from: i)
        checkWin()
        if state == .playing {
            SoundPlayer.shared.play(.reveal)
        }
    }

    // 點擊已翻開的數字：周圍旗子數相同時，翻開其餘格子
    private func chord(_ i: Int) {
        let n = neighbors(i)
        let flags = n.filter { cells[$0].flagged }.count
        guard cells[i].adjacent > 0, flags == cells[i].adjacent else { return }
        for j in n where !cells[j].flagged && !cells[j].revealed {
            if cells[j].mine {
                lose(exploded: j)
                return
            }
            flood(from: j)
        }
        checkWin()
        if state == .playing {
            SoundPlayer.shared.play(.reveal)
        }
    }

    private func flood(from start: Int) {
        var stack = [start]
        while let i = stack.popLast() {
            guard !cells[i].revealed, !cells[i].flagged, !cells[i].mine else { continue }
            cells[i].revealed = true
            if cells[i].adjacent == 0 {
                stack.append(contentsOf: neighbors(i))
            }
        }
    }

    private func placeMines(safe: Int) {
        let excluded = Set(neighbors(safe) + [safe])
        var candidates = Array(cells.indices.filter { !excluded.contains($0) })
        candidates.shuffle()
        for i in candidates.prefix(difficulty.mines) {
            cells[i].mine = true
        }
        for i in cells.indices {
            cells[i].adjacent = neighbors(i).filter { cells[$0].mine }.count
        }
    }

    private func lose(exploded i: Int) {
        state = .lost
        stopTimer()
        SoundPlayer.shared.play(.explosion)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        cells[i].exploded = true
        for j in cells.indices where cells[j].mine && !cells[j].flagged {
            cells[j].revealed = true
        }
    }

    private func checkWin() {
        let hidden = cells.filter { !$0.revealed }.count
        guard hidden == difficulty.mines else { return }
        state = .won
        stopTimer()
        SoundPlayer.shared.play(.win)
        for j in cells.indices where cells[j].mine {
            cells[j].flagged = true
        }
    }

    func neighbors(_ i: Int) -> [Int] {
        let r = i / cols, c = i % cols
        var result: [Int] = []
        for dr in -1...1 {
            for dc in -1...1 where !(dr == 0 && dc == 0) {
                let nr = r + dr, nc = c + dc
                if nr >= 0, nr < rows, nc >= 0, nc < cols {
                    result.append(nr * cols + nc)
                }
            }
        }
        return result
    }

    private func startTimer() {
        elapsed = 1
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                if self.elapsed < 999 { self.elapsed += 1 }
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
}
