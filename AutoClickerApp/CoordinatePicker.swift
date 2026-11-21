import AppKit
import SwiftUI
import CoreGraphics

public class CoordinatePickerManager: ObservableObject {
    public static let shared = CoordinatePickerManager()

    @Published public var isPicking: Bool = false
    @Published public var currentCoordinates: CGPoint = .zero
    @Published public var promptText: String = "Move cursor to target. Press SPACE or CLICK to capture."

    private var pickerWindow: NSPanel?
    private var eventMonitor: Any?
    private var globalMonitor: Any?
    private var timer: Timer?
    private var completionHandler: ((CGPoint?) -> Void)?

    private init() {}

    public func startPicking(prompt: String = "Move cursor to target. Press SPACE or CLICK to capture.", completion: @escaping (CGPoint?) -> Void) {
        guard !isPicking else { return }

        self.isPicking = true
        self.promptText = prompt
        self.completionHandler = completion
        self.currentCoordinates = InputSimulator.shared.currentMouseLocation()

        showFloatingHUD()

        // Timer to track mouse position smoothly
        timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let loc = InputSimulator.shared.currentMouseLocation()
            DispatchQueue.main.async {
                self.currentCoordinates = loc
            }
        }

        // Global monitor for clicks & keypresses
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .keyDown]) { [weak self] event in
            self?.handleEvent(event)
        }

        // Local monitor (in case the panel has focus)
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .keyDown]) { [weak self] event in
            self?.handleEvent(event)
            return nil
        }
    }

    private func handleEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            finishPicking(success: true)
        } else if event.type == .keyDown {
            if event.keyCode == 49 { // Spacebar
                finishPicking(success: true)
            } else if event.keyCode == 53 { // Escape
                finishPicking(success: false)
            }
        }
    }

    public func finishPicking(success: Bool) {
        let finalPoint = currentCoordinates
        isPicking = false

        if let em = eventMonitor {
            NSEvent.removeMonitor(em)
            eventMonitor = nil
        }
        if let gm = globalMonitor {
            NSEvent.removeMonitor(gm)
            globalMonitor = nil
        }
        timer?.invalidate()
        timer = nil

        pickerWindow?.orderOut(nil)
        pickerWindow = nil

        let handler = completionHandler
        completionHandler = nil

        DispatchQueue.main.async {
            handler?(success ? finalPoint : nil)
        }
    }

    private func showFloatingHUD() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 110),
            styleMask: [.nonactivatingPanel, .titled, .hudWindow],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.isOpaque = false
        panel.backgroundColor = NSColor.clear
        panel.hasShadow = true
        panel.title = "Target Coordinate Picker"

        let hostingView = NSHostingView(rootView: CoordinatePickerHUDView(manager: self))
        panel.contentView = hostingView

        // Center on top screen
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.midX - 220
            let y = screenRect.maxY - 140
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFrontRegardless()
        self.pickerWindow = panel
    }
}

public struct CoordinatePickerHUDView: View {
    @ObservedObject var manager: CoordinatePickerManager

    public var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "scope")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("COORDINATE PICKER ACTIVE")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Button("Cancel (ESC)") {
                    manager.finishPicking(success: false)
                }
                .controlSize(.small)
            }

            Text(manager.promptText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Text("X:").fontWeight(.bold)
                    Text("\(Int(manager.currentCoordinates.x))")
                        .font(.system(.title3, design: .monospaced))
                        .foregroundColor(.blue)
                }
                HStack(spacing: 6) {
                    Text("Y:").fontWeight(.bold)
                    Text("\(Int(manager.currentCoordinates.y))")
                        .font(.system(.title3, design: .monospaced))
                        .foregroundColor(.green)
                }
                Spacer()
                Button("Lock Coordinate (Space)") {
                    manager.finishPicking(success: true)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .shadow(radius: 12)
        )
        .frame(width: 440, height: 110)
    }
}
