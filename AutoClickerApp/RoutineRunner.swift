import Foundation
import CoreGraphics
import AppKit

public class RoutineRunner: ObservableObject {
    public static let shared = RoutineRunner()

    @Published public var isExecuting: Bool = false
    @Published public var isCountingDown: Bool = false
    @Published public var countdownRemaining: Int = 0
    @Published public var currentCycle: Int = 0
    @Published public var totalCycles: Int? = nil
    @Published public var currentStepIndex: Int? = nil
    @Published public var statusMessage: String = "Ready"

    private var stopRequested: Bool = false
    private var runnerQueue = DispatchQueue(label: "com.autoclicker.runner", qos: .userInteractive)
    private var globalEventMonitor: Any?
    private var globalTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private init() {}

    public func startRoutine(settings: RoutineSettings, steps: [RoutineStep]) {
        guard !isExecuting else { return }

        // Accessibility Permission check
        if !AXIsProcessTrusted() {
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options)
            DispatchQueue.main.async {
                self.statusMessage = "Accessibility permission needed. Please grant in System Settings."
            }
            return
        }

        stopRequested = false
        isExecuting = true
        currentCycle = 0
        totalCycles = settings.isInfiniteRepeat ? nil : settings.repeatCount
        currentStepIndex = nil
        statusMessage = "Starting routine..."

        installGlobalEscListener()

        // Minimize application window immediately after routine starts
        DispatchQueue.main.async {
            for window in NSApp.windows {
                if !(window is NSPanel) && window.isVisible && !window.isMiniaturized {
                    window.miniaturize(nil)
                }
            }
        }

        runnerQueue.async { [weak self] in
            guard let self = self else { return }

            // 1. Initial Countdown
            let countdown = Int(settings.initialCountdown)
            if countdown > 0 {
                DispatchQueue.main.async {
                    self.isCountingDown = true
                }

                for sec in (1...countdown).reversed() {
                    if self.stopRequested { break }
                    DispatchQueue.main.async {
                        self.countdownRemaining = sec
                        self.statusMessage = "Starting in \(sec) seconds... (Press ESC to cancel)"
                    }
                    self.interruptibleSleep(1.0)
                }

                DispatchQueue.main.async {
                    self.isCountingDown = false
                }
            }

            if self.stopRequested {
                self.cleanupRoutine(message: "Cancelled before start.")
                return
            }

            DispatchQueue.main.async {
                self.statusMessage = "Routine running. Press ESC to stop."
            }

            let enabledSteps = steps.filter { $0.isEnabled }
            guard !enabledSteps.isEmpty else {
                self.cleanupRoutine(message: "No enabled steps to execute.")
                return
            }

            var cycle = 0
            while !self.stopRequested {
                cycle += 1
                DispatchQueue.main.async {
                    self.currentCycle = cycle
                }

                if let max = self.totalCycles, cycle > max {
                    break
                }

                for (idx, step) in enabledSteps.enumerated() {
                    if self.stopRequested { break }

                    DispatchQueue.main.async {
                        self.currentStepIndex = idx
                        self.statusMessage = "Cycle \(cycle) • Step \(idx + 1): \(step.kind.rawValue)"
                    }

                    self.executeStep(step)

                    // Universal delay between steps
                    if !self.stopRequested && settings.universalStepDelay > 0 {
                        self.interruptibleSleep(settings.universalStepDelay)
                    }
                }
            }

            let finalMsg = self.stopRequested ? "Stopped by user (ESC). Completed \(cycle - 1) cycles." : "Completed all \(settings.repeatCount) cycles."
            self.cleanupRoutine(message: finalMsg)
        }
    }

    public func stopRoutine() {
        stopRequested = true
        DispatchQueue.main.async {
            self.statusMessage = "Stopping..."
        }
    }

    private func executeStep(_ step: RoutineStep) {
        switch step.kind {
        case .keystroke:
            if let code = KeyCodeHelper.keyCode(for: step.keyText) {
                InputSimulator.shared.sendKey(code: code)
            }

        case .keystrokeWithModifiers:
            if let code = KeyCodeHelper.keyCode(for: step.keyText) {
                let flags = KeyCodeHelper.flags(for: step.modifiers)
                InputSimulator.shared.sendKey(code: code, flags: flags)
            }

        case .mouseLeftClick:
            let point: CGPoint
            if step.clickCurrentPosition {
                point = InputSimulator.shared.currentMouseLocation()
            } else {
                point = CGPoint(x: step.leftClickX, y: step.leftClickY)
            }
            InputSimulator.shared.leftClick(at: point, isDoubleClick: step.doubleClick)

        case .mouseRightClick:
            let point = CGPoint(x: step.rightClickX, y: step.rightClickY)
            InputSimulator.shared.rightClick(at: point)

            if step.selectMenuOption {
                // Short wait for menu animation
                interruptibleSleep(max(0.1, step.menuDelay))
                if !stopRequested {
                    let optPoint = CGPoint(x: step.menuOptionX, y: step.menuOptionY)
                    InputSimulator.shared.leftClick(at: optPoint)
                }
            }

        case .delayTimer:
            interruptibleSleep(max(0.01, step.delaySeconds))
        }
    }

    // Sleeps in 20ms slices to react instantly to ESC
    private func interruptibleSleep(_ seconds: Double) {
        let totalMs = Int(seconds * 1000)
        let sliceMs = 20
        var elapsed = 0
        while !stopRequested && elapsed < totalMs {
            let sleepTime = min(sliceMs, totalMs - elapsed)
            usleep(useconds_t(sleepTime * 1000))
            elapsed += sleepTime
        }
    }

    private func installGlobalEscListener() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53 { // ESC keycode
                    self?.stopRoutine()
                }
            }
        }
    }

    private func cleanupRoutine(message: String) {
        DispatchQueue.main.async {
            self.isExecuting = false
            self.isCountingDown = false
            self.currentStepIndex = nil
            self.statusMessage = message

            if let monitor = self.globalEventMonitor {
                NSEvent.removeMonitor(monitor)
                self.globalEventMonitor = nil
            }

            // Restore application window when routine finishes or is stopped
            for window in NSApp.windows {
                if !(window is NSPanel) && window.isMiniaturized {
                    window.deminiaturize(nil)
                }
            }
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
