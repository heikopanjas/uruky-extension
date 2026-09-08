import SwiftUI

@main
struct StartpageApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        .defaultSize(width: 460, height: 420)
        #endif
    }
}
