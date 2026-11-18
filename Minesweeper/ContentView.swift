import SwiftUI

@main
struct MinesweeperApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var game = Game()
    @State private var pressing = false

    private let frameInset: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            let cell = cellSize(in: geo.size)
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                window(cell: cell)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 10)
        .background(Color.winGray.ignoresSafeArea())
        .preferredColorScheme(.light)
        .onAppear { _ = SoundPlayer.shared }  // 先把音效準備好，第一次點擊才不會卡
    }

    private func cellSize(in size: CGSize) -> CGFloat {
        let chrome: CGFloat = 2 * (3 + frameInset + 3)
        let byWidth = (size.width - chrome) / CGFloat(game.cols)
        let byHeight = (size.height - 150) / CGFloat(game.rows)
        return floor(min(byWidth, byHeight, 44))
    }

    private func window(cell: CGFloat) -> some View {
        VStack(spacing: frameInset) {
            header
            board(cell: cell)
            controls
        }
        .padding(frameInset + 3)
        .background(Color.winGray)
        .bevel(raised: true, width: 3)
    }

    // MARK: 計數器 + 笑臉

    private var header: some View {
        HStack {
            LEDCounter(value: game.minesLeft)
            Spacer()
            Button { game.reset() } label: {
                SmileyFace(mood: mood)
                    .padding(5)
                    .frame(width: 46, height: 46)
                    .background(Color.winGray)
                    .bevel(raised: true, width: 3)
                    .overlay(Rectangle().stroke(Color.winDark, lineWidth: 1))
            }
            .buttonStyle(.plain)
            Spacer()
            LEDCounter(value: game.elapsed)
        }
        .padding(6)
        .bevel(raised: false, width: 2)
    }

    private var mood: SmileyFace.Mood {
        switch game.state {
        case .won: .cool
        case .lost: .dead
        default: pressing ? .worried : .happy
        }
    }

    // MARK: 雷區

    private func board(cell: CGFloat) -> some View {
        BoardView(
            cells: game.cells,
            rows: game.rows,
            cols: game.cols,
            lost: game.state == .lost,
            size: cell,
            onTap: { game.tap($0) },
            onFlag: { i in
                guard i < game.cells.count, !game.cells[i].revealed, !game.isOver else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                game.toggleFlag(i)
            },
            onPressing: { i, down in
                pressing = down && !game.isOver && i < game.cells.count && !game.cells[i].revealed
            }
        )
        .id(game.difficulty)
        .padding(3)
        .bevel(raised: false, width: 3)
    }

    // MARK: 難度 + 插旗模式

    private var controls: some View {
        HStack(spacing: 6) {
            ForEach(Difficulty.allCases) { d in
                ClassicButton(pressed: game.difficulty == d) {
                    Text(d.label)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                } action: {
                    game.reset(d)
                }
            }
            Spacer(minLength: 0)
            ClassicButton(pressed: game.flagMode) {
                FlagIcon().frame(width: 26, height: 26)
            } action: {
                game.flagMode.toggle()
            }
        }
    }
}

// 以快照資料繪製雷區，避免切換難度時舊格子讀到新陣列而越界
struct BoardView: View {
    let cells: [Cell]
    let rows: Int
    let cols: Int
    let lost: Bool
    let size: CGFloat
    let onTap: (Int) -> Void
    let onFlag: (Int) -> Void
    let onPressing: (Int, Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<cols, id: \.self) { c in
                        let i = r * cols + c
                        if i < cells.count {
                            CellView(cell: cells[i], lost: lost, size: size)
                                .contentShape(Rectangle())
                                .onTapGesture { onTap(i) }
                                .onLongPressGesture(minimumDuration: 0.3) {
                                    onFlag(i)
                                } onPressingChanged: { down in
                                    onPressing(i, down)
                                }
                        }
                    }
                }
            }
        }
    }
}

struct ClassicButton<Label: View>: View {
    var pressed: Bool
    @ViewBuilder var label: Label
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .offset(x: pressed ? 1 : 0, y: pressed ? 1 : 0)
                .frame(minWidth: 52, minHeight: 38)
                .padding(.horizontal, 4)
                .background(pressed ? Color(white: 0.68) : .winGray)
                .bevel(raised: !pressed, width: 3)
        }
        .buttonStyle(.plain)
    }
}

struct CellView: View {
    let cell: Cell
    let lost: Bool
    let size: CGFloat

    private static let numberColors: [Color] = [
        .clear,
        Color(red: 0, green: 0, blue: 1),
        Color(red: 0, green: 0.5, blue: 0),
        Color(red: 1, green: 0, blue: 0),
        Color(red: 0, green: 0, blue: 0.5),
        Color(red: 0.5, green: 0, blue: 0),
        Color(red: 0, green: 0.5, blue: 0.5),
        .black,
        Color.winDark,
    ]

    var body: some View {
        ZStack {
            if cell.revealed {
                revealed
            } else {
                Color.winGray
                    .bevel(raised: true, width: max(2, size * 0.12))
                if cell.flagged {
                    if lost && !cell.mine {
                        // 插錯旗：顯示打叉的地雷
                        Color.winGray
                            .overlay(alignment: .bottomTrailing) { gridLines }
                        MineIcon().padding(size * 0.1)
                        CrossIcon().padding(size * 0.08)
                    } else {
                        FlagIcon().padding(size * 0.12)
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    private var revealed: some View {
        ZStack {
            (cell.exploded ? Color.red : Color.winGray)
            gridLines
            if cell.mine {
                MineIcon().padding(size * 0.1)
            } else if cell.adjacent > 0 {
                Text("\(cell.adjacent)")
                    .font(.system(size: size * 0.7, weight: .black, design: .rounded))
                    .foregroundStyle(Self.numberColors[cell.adjacent])
            }
        }
    }

    // 已翻開格子之間的細灰線
    private var gridLines: some View {
        Canvas { ctx, s in
            var p = Path()
            p.move(to: .init(x: 0, y: 0.5)); p.addLine(to: .init(x: s.width, y: 0.5))
            p.move(to: .init(x: 0.5, y: 0)); p.addLine(to: .init(x: 0.5, y: s.height))
            ctx.stroke(p, with: .color(.winDark), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    ContentView()
}
