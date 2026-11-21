import Foundation
import CoreGraphics

// MARK: - Action Types

public enum ActionKind: String, Codable, CaseIterable, Identifiable {
    case keystroke = "Keystroke"
    case keystrokeWithModifiers = "Keystroke with Modifiers"
    case mouseLeftClick = "Mouse Left Click"
    case mouseRightClick = "Mouse Right Click"
    case delayTimer = "Delay Timer"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .keystroke: return "keyboard"
        case .keystrokeWithModifiers: return "command"
        case .mouseLeftClick: return "cursorarrow.rays"
        case .mouseRightClick: return "contextualmenu.and.cursorarrow"
        case .delayTimer: return "timer"
        }
    }
}

// MARK: - Modifier Keys

public struct ModifierKey: OptionSet, Codable, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let command = ModifierKey(rawValue: 1 << 0)
    public static let option  = ModifierKey(rawValue: 1 << 1)
    public static let control = ModifierKey(rawValue: 1 << 2)
    public static let shift   = ModifierKey(rawValue: 1 << 3)

    public var symbol: String {
        switch self {
        case .command: return "⌘"
        case .option:  return "⌥"
        case .control: return "⌃"
        case .shift:   return "⇧"
        default:       return ""
        }
    }

    public var label: String {
        switch self {
        case .command: return "Cmd (⌘)"
        case .option:  return "Opt (⌥)"
        case .control: return "Ctrl (⌃)"
        case .shift:   return "Shift (⇧)"
        default:       return ""
        }
    }
}

// MARK: - Routine Step Model

public struct RoutineStep: Identifiable, Codable, Equatable {
    public var id: UUID
    public var isEnabled: Bool
    public var kind: ActionKind

    // Keystroke configuration
    public var keyText: String
    public var modifiers: [String] // "command", "option", "control", "shift"

    // Mouse Left Click configuration
    public var clickCurrentPosition: Bool
    public var leftClickX: Double
    public var leftClickY: Double
    public var doubleClick: Bool

    // Mouse Right Click configuration
    public var rightClickX: Double
    public var rightClickY: Double
    public var selectMenuOption: Bool
    public var menuOptionX: Double
    public var menuOptionY: Double
    public var menuDelay: Double

    // Delay Timer configuration
    public var delaySeconds: Double

    public init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        kind: ActionKind = .keystroke,
        keyText: String = "d",
        modifiers: [String] = [],
        clickCurrentPosition: Bool = true,
        leftClickX: Double = 500,
        leftClickY: Double = 500,
        doubleClick: Bool = false,
        rightClickX: Double = 500,
        rightClickY: Double = 500,
        selectMenuOption: Bool = false,
        menuOptionX: Double = 500,
        menuOptionY: Double = 530,
        menuDelay: Double = 0.25,
        delaySeconds: Double = 1.0
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.kind = kind
        self.keyText = keyText
        self.modifiers = modifiers
        self.clickCurrentPosition = clickCurrentPosition
        self.leftClickX = leftClickX
        self.leftClickY = leftClickY
        self.doubleClick = doubleClick
        self.rightClickX = rightClickX
        self.rightClickY = rightClickY
        self.selectMenuOption = selectMenuOption
        self.menuOptionX = menuOptionX
        self.menuOptionY = menuOptionY
        self.menuDelay = menuDelay
        self.delaySeconds = delaySeconds
    }

    public static func defaultFiveSteps() -> [RoutineStep] {
        return [
            // Step 1: Keystroke (Down Arrow)
            RoutineStep(
                kind: .keystroke,
                keyText: "down"
            ),
            // Step 2: Keystroke (Letter 'd')
            RoutineStep(
                kind: .keystroke,
                keyText: "d"
            ),
            // Step 3: Mouse Left Click (Current cursor position)
            RoutineStep(
                kind: .mouseLeftClick,
                clickCurrentPosition: true
            ),
            // Step 4: Delay Timer (0.5s pause)
            RoutineStep(
                kind: .delayTimer,
                delaySeconds: 0.5
            ),
            // Step 5: Keystroke with Modifiers (e.g., Command + S or custom)
            RoutineStep(
                kind: .keystrokeWithModifiers,
                keyText: "s",
                modifiers: ["command"]
            )
        ]
    }
}

// MARK: - Routine Settings

public struct RoutineSettings: Codable, Equatable {
    public var initialCountdown: Double
    public var universalStepDelay: Double
    public var isInfiniteRepeat: Bool
    public var repeatCount: Int
    public var startHotkey: String

    public init(
        initialCountdown: Double = 3.0,
        universalStepDelay: Double = 0.5,
        isInfiniteRepeat: Bool = true,
        repeatCount: Int = 10,
        startHotkey: String = "F6"
    ) {
        self.initialCountdown = initialCountdown
        self.universalStepDelay = universalStepDelay
        self.isInfiniteRepeat = isInfiniteRepeat
        self.repeatCount = repeatCount
        self.startHotkey = startHotkey
    }
}

// MARK: - Complete Profile

public struct RoutineProfile: Codable {
    public var name: String
    public var settings: RoutineSettings
    public var steps: [RoutineStep]

    public init(name: String = "Default Profile", settings: RoutineSettings = RoutineSettings(), steps: [RoutineStep] = RoutineStep.defaultFiveSteps()) {
        self.name = name
        self.settings = settings
        self.steps = steps
    }
}
