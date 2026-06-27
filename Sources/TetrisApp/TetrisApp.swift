import SwiftUI

@main
struct TetrisApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .frame(minWidth: 900, minHeight: 720)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
