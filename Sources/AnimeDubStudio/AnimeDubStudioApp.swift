import SwiftUI
import AppKit
import AnimeDubCore

@main
struct AnimeDubStudioApp: App {
    var body: some Scene {
        WindowGroup {
            StudioContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .newItem) {
                Button("New Dub Project...") {
                    // Handled inside StudioContentView
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        Settings {
            SettingsView(viewModel: StudioViewModel())
                .frame(width: 520, height: 420)
        }
    }
}
