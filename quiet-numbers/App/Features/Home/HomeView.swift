import QuietNumbersCore
import SwiftUI

struct HomeView: View {
    @State private var game: GameModel?
    @State private var isPlaying = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()
                Text(verbatim: "Quiet Numbers")
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                VStack(spacing: 12) {
                    if let game, !game.session.isOver {
                        Button {
                            isPlaying = true
                        } label: {
                            Text("Continue").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Button {
                        game = GameModel()
                        isPlaying = true
                    } label: {
                        Text("New Game").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)
                .buttonBorderShape(.capsule)
                .frame(maxWidth: 320)
                Spacer()
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.background)
            .navigationDestination(isPresented: $isPlaying) {
                if let game {
                    GameView(model: game) { self.game = GameModel() }
                }
            }
        }
        #if DEBUG
        .onAppear {
            // Screenshots and UI tests: `-startGame` opens a game right away;
            // `-seedKey <text>` makes its board deterministic and
            // `-boardValues 5,3,7,…` starts from exact numbers.
            let arguments = ProcessInfo.processInfo.arguments
            func value(after flag: String) -> String? {
                guard let i = arguments.firstIndex(of: flag), i + 1 < arguments.count else { return nil }
                return arguments[i + 1]
            }
            if arguments.contains("-startGame"), game == nil {
                if let values = value(after: "-boardValues") {
                    game = GameModel(session: GameSession(values: values.split(separator: ",").compactMap { Int($0) }, seed: 0))
                } else if let key = value(after: "-seedKey") {
                    game = GameModel(session: GameSession(seed: FNV1a.hash(key)))
                } else {
                    game = GameModel()
                }
                isPlaying = true
            }
        }
        #endif
    }
}
