import Foundation
import CoreGraphics
import Carbon.HIToolbox

public enum KeyCodeHelper {
    public static func keyCode(for string: String) -> CGKeyCode? {
        let lower = string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Special keys mapping
        switch lower {
        case "down", "downarrow", "down_arrow", "arrowdown": return 0x7D
        case "up", "uparrow", "up_arrow", "arrowup":       return 0x7E
        case "left", "leftarrow", "left_arrow", "arrowleft":   return 0x7B
        case "right", "rightarrow", "right_arrow", "arrowright": return 0x7C
        case "return", "enter":                              return 0x24
        case "tab":                                          return 0x30
        case "space", "spacebar", " ":                       return 0x31
        case "delete", "backspace":                          return 0x33
        case "escape", "esc":                                return 0x35
        case "capslock", "caps_lock":                        return 0x39
        case "f1":  return 0x7A
        case "f2":  return 0x78
        case "f3":  return 0x63
        case "f4":  return 0x76
        case "f5":  return 0x60
        case "f6":  return 0x61
        case "f7":  return 0x62
        case "f8":  return 0x64
        case "f9":  return 0x65
        case "f10": return 0x6D
        case "f11": return 0x67
        case "f12": return 0x6F
        default: break
        }

        // Letter & number mapping
        if let char = lower.first, lower.count == 1 {
            switch char {
            case "a": return 0x00
            case "s": return 0x01
            case "d": return 0x02
            case "f": return 0x03
            case "h": return 0x04
            case "g": return 0x05
            case "z": return 0x06
            case "x": return 0x07
            case "c": return 0x08
            case "v": return 0x09
            case "b": return 0x0B
            case "q": return 0x0C
            case "w": return 0x0D
            case "e": return 0x0E
            case "r": return 0x0F
            case "y": return 0x10
            case "t": return 0x11
            case "1": return 0x12
            case "2": return 0x13
            case "3": return 0x14
            case "4": return 0x15
            case "6": return 0x16
            case "5": return 0x17
            case "=": return 0x18
            case "9": return 0x19
            case "7": return 0x1A
            case "-": return 0x1B
            case "8": return 0x1C
            case "0": return 0x1D
            case "]": return 0x1E
            case "o": return 0x1F
            case "u": return 0x20
            case "[": return 0x21
            case "i": return 0x22
            case "p": return 0x23
            case "l": return 0x25
            case "j": return 0x26
            case "'": return 0x27
            case "k": return 0x28
            case ";": return 0x29
            case "\\": return 0x2A
            case ",": return 0x2B
            case "/": return 0x2C
            case "n": return 0x2D
            case "m": return 0x2E
            case ".": return 0x2F
            default: return nil
            }
        }
        return nil
    }

    public static func flags(for modifiers: [String]) -> CGEventFlags {
        var eventFlags = CGEventFlags()
        for mod in modifiers {
            switch mod.lowercased() {
            case "command", "cmd": eventFlags.insert(.maskCommand)
            case "option", "alt", "opt": eventFlags.insert(.maskAlternate)
            case "control", "ctrl": eventFlags.insert(.maskControl)
            case "shift": eventFlags.insert(.maskShift)
            default: break
            }
        }
        return eventFlags
    }
}

public class InputSimulator {
    public static let shared = InputSimulator()

    private init() {}

    // Get current mouse cursor position in CoreGraphics coordinates
    public func currentMouseLocation() -> CGPoint {
        if let event = CGEvent(source: nil) {
            return event.location
        }
        return CGPoint(x: 500, y: 500)
    }

    // Press and release key
    public func sendKey(code: CGKeyCode, flags: CGEventFlags = []) {
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false) else {
            return
        }

        if !flags.isEmpty {
            down.flags = flags
            up.flags = flags
        }

        down.post(tap: .cghidEventTap)
        usleep(18000) // 18ms key hold time
        up.post(tap: .cghidEventTap)
    }

    // Left mouse click
    public func leftClick(at point: CGPoint, isDoubleClick: Bool = false) {
        guard let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
              let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) else {
            return
        }

        if isDoubleClick {
            down.setIntegerValueField(.mouseEventClickState, value: 1)
            up.setIntegerValueField(.mouseEventClickState, value: 1)
            down.post(tap: .cghidEventTap)
            usleep(15000)
            up.post(tap: .cghidEventTap)
            usleep(40000)

            guard let down2 = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
                  let up2 = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) else {
                return
            }
            down2.setIntegerValueField(.mouseEventClickState, value: 2)
            up2.setIntegerValueField(.mouseEventClickState, value: 2)
            down2.post(tap: .cghidEventTap)
            usleep(15000)
            up2.post(tap: .cghidEventTap)
        } else {
            down.post(tap: .cghidEventTap)
            usleep(18000)
            up.post(tap: .cghidEventTap)
        }
    }

    // Right mouse click
    public func rightClick(at point: CGPoint) {
        guard let down = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown, mouseCursorPosition: point, mouseButton: .right),
              let up = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp, mouseCursorPosition: point, mouseButton: .right) else {
            return
        }

        down.post(tap: .cghidEventTap)
        usleep(18000)
        up.post(tap: .cghidEventTap)
    }
}
