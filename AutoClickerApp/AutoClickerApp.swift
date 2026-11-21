import SwiftUI
import AppKit

@main
struct AutoClickerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandMenu("Routine") {
                Button("Start Routine") {
                    // Trigger via routine runner if not running
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("Stop Routine") {
                    RoutineRunner.shared.stopRoutine()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var globalKeyDownMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)

        // Set application dock icon
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let iconImage = NSImage(contentsOfFile: iconPath) {
            NSApplication.shared.applicationIconImage = iconImage
        }

        // Install global F6 hotkey monitor
        globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            // 0x61 = F6 keycode
            if event.keyCode == 0x61 {
                DispatchQueue.main.async {
                    if RoutineRunner.shared.isExecuting {
                        RoutineRunner.shared.stopRoutine()
                    }
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = globalKeyDownMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyDownMonitor = nil
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
