import SwiftUI

public struct StepRowView: View {
    @Binding var step: RoutineStep
    var index: Int
    var isCurrentStep: Bool
    var totalSteps: Int
    var onMoveUp: () -> Void
    var onMoveDown: () -> Void
    var onDuplicate: () -> Void
    var onDelete: () -> Void

    let specialKeys = ["down", "up", "left", "right", "return", "space", "tab", "delete", "escape"]

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header Row: Step number, Enable toggle, Action Dropdown, Actions
            HStack(spacing: 10) {
                Toggle("", isOn: $step.isEnabled)
                    .labelsHidden()
                    .help("Enable or Disable this step")

                HStack(spacing: 5) {
                    Image(systemName: step.kind.iconName)
                        .font(.system(size: 14))
                        .foregroundColor(step.isEnabled ? .accentColor : .secondary)
                    Text("Step \(index + 1)")
                        .font(.system(size: 13.5, weight: .bold))
                }

                Picker("", selection: $step.kind) {
                    ForEach(ActionKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 200)
                .font(.system(size: 13))

                Spacer()

                // Card actions
                HStack(spacing: 6) {
                    Button(action: onMoveUp) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .disabled(index == 0)
                    .help("Move step up")

                    Button(action: onMoveDown) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .disabled(index == totalSteps - 1)
                    .help("Move step down")

                    Button(action: onDuplicate) {
                        Image(systemName: "plus.square.on.square")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .help("Duplicate this step")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(.red)
                    }
                    .disabled(totalSteps <= 1)
                    .help("Delete this step")
                }
                .buttonStyle(.borderless)
            }

            Divider()

            // Context-sensitive dynamic controls based on ActionKind
            if step.isEnabled {
                dynamicControls
            } else {
                Text("Step is disabled and will be skipped.")
                    .font(.system(size: 12.5))
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isCurrentStep ? Color.green : Color.clear, lineWidth: 2)
        )
    }

    @ViewBuilder
    private var dynamicControls: some View {
        switch step.kind {
        case .keystroke:
            keystrokeControls

        case .keystrokeWithModifiers:
            keystrokeWithModifiersControls

        case .mouseLeftClick:
            mouseLeftClickControls

        case .mouseRightClick:
            mouseRightClickControls

        case .delayTimer:
            delayTimerControls
        }
    }

    // 1. Keystroke controls
    private var keystrokeControls: some View {
        HStack(spacing: 10) {
            Text("Key:")
                .font(.system(size: 13, weight: .medium))

            TextField("e.g. d, down, return", text: $step.keyText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .frame(width: 130)

            Menu("Presets") {
                ForEach(specialKeys, id: \.self) { sk in
                    Button(sk.capitalized) {
                        step.keyText = sk
                    }
                }
            }
            .font(.system(size: 13))
            .frame(width: 105)

            Text("(letter or name: down, return, space)")
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
        }
    }

    // 2. Keystroke with Modifiers controls
    private var keystrokeWithModifiersControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Modifiers:")
                    .font(.system(size: 13, weight: .medium))

                modifierToggle(title: "⌘ Cmd", key: "command")
                modifierToggle(title: "⌥ Opt", key: "option")
                modifierToggle(title: "⌃ Ctrl", key: "control")
                modifierToggle(title: "⇧ Shift", key: "shift")
            }

            HStack(spacing: 10) {
                Text("Key:")
                    .font(.system(size: 13, weight: .medium))

                TextField("e.g. s, c, down", text: $step.keyText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .frame(width: 120)

                Menu("Presets") {
                    ForEach(specialKeys, id: \.self) { sk in
                        Button(sk.capitalized) {
                            step.keyText = sk
                        }
                    }
                }
                .font(.system(size: 13))
                .frame(width: 105)

                let combo = formattedCombo()
                Text("Combo: \(combo)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.accentColor)
            }
        }
    }

    private func modifierToggle(title: String, key: String) -> some View {
        let isSelected = step.modifiers.contains(key)
        return Button(action: {
            if isSelected {
                step.modifiers.removeAll { $0 == key }
            } else {
                step.modifiers.append(key)
            }
        }) {
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(isSelected ? Color.accentColor : Color(NSColor.controlColor))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(5)
        }
        .buttonStyle(.plain)
    }

    private func formattedCombo() -> String {
        var parts: [String] = []
        if step.modifiers.contains("command") { parts.append("⌘") }
        if step.modifiers.contains("option")  { parts.append("⌥") }
        if step.modifiers.contains("control") { parts.append("⌃") }
        if step.modifiers.contains("shift")   { parts.append("⇧") }
        parts.append(step.keyText.isEmpty ? "?" : step.keyText.uppercased())
        return parts.joined(separator: " + ")
    }

    // 3. Mouse Left Click controls
    private var mouseLeftClickControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 14) {
                Picker("Position:", selection: $step.clickCurrentPosition) {
                    Text("Current Cursor").tag(true)
                    Text("Coordinates (X, Y)").tag(false)
                }
                .pickerStyle(.radioGroup)
                .horizontalRadioGroupLayout()
                .font(.system(size: 13))

                Toggle("Double Click", isOn: $step.doubleClick)
                    .font(.system(size: 13))
                    .padding(.leading, 8)
            }

            if !step.clickCurrentPosition {
                HStack(spacing: 8) {
                    Text("Target:")
                        .font(.system(size: 13, weight: .medium))

                    Text("X:").font(.system(size: 13))
                    TextField("X", value: $step.leftClickX, formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                        .frame(width: 65)

                    Text("Y:").font(.system(size: 13))
                    TextField("Y", value: $step.leftClickY, formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                        .frame(width: 65)

                    Button(action: {
                        CoordinatePickerManager.shared.startPicking(prompt: "Step \(index + 1): Hover over Left-Click target and press SPACE or CLICK.") { point in
                            if let p = point {
                                step.leftClickX = Double(Int(p.x))
                                step.leftClickY = Double(Int(p.y))
                            }
                        }
                    }) {
                        Label("Pick Coordinates", systemImage: "scope")
                            .font(.system(size: 12.5, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    // 4. Mouse Right Click controls
    private var mouseRightClickControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Right Click:")
                    .font(.system(size: 13, weight: .medium))

                Text("X:").font(.system(size: 13))
                TextField("X", value: $step.rightClickX, formatter: NumberFormatter())
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .frame(width: 65)

                Text("Y:").font(.system(size: 13))
                TextField("Y", value: $step.rightClickY, formatter: NumberFormatter())
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .frame(width: 65)

                Button(action: {
                    CoordinatePickerManager.shared.startPicking(prompt: "Step \(index + 1): Hover over Right-Click location and press SPACE or CLICK.") { point in
                        if let p = point {
                            step.rightClickX = Double(Int(p.x))
                            step.rightClickY = Double(Int(p.y))
                        }
                    }
                }) {
                    Label("Pick", systemImage: "scope")
                        .font(.system(size: 12.5, weight: .medium))
                }
                .buttonStyle(.bordered)

                Toggle("Select Menu Option After", isOn: $step.selectMenuOption)
                    .font(.system(size: 13))
                    .padding(.leading, 6)
            }

            if step.selectMenuOption {
                HStack(spacing: 8) {
                    Text("Option:")
                        .font(.system(size: 13, weight: .medium))

                    Text("X:").font(.system(size: 13))
                    TextField("X", value: $step.menuOptionX, formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                        .frame(width: 65)

                    Text("Y:").font(.system(size: 13))
                    TextField("Y", value: $step.menuOptionY, formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                        .frame(width: 65)

                    Button(action: {
                        CoordinatePickerManager.shared.startPicking(prompt: "Step \(index + 1): Hover over Menu Item and press SPACE or CLICK.") { point in
                            if let p = point {
                                step.menuOptionX = Double(Int(p.x))
                                step.menuOptionY = Double(Int(p.y))
                            }
                        }
                    }) {
                        Label("Pick", systemImage: "scope")
                            .font(.system(size: 12.5, weight: .medium))
                    }
                    .buttonStyle(.bordered)

                    Text("Menu Delay:").font(.system(size: 13))
                    TextField("s", value: $step.menuDelay, format: .number.precision(.fractionLength(2)))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                        .frame(width: 52)
                    Text("s").font(.system(size: 12)).foregroundColor(.secondary)
                }
                .padding(.leading, 8)
            }
        }
    }

    // 5. Delay Timer controls
    private var delayTimerControls: some View {
        HStack(spacing: 10) {
            Text("Wait Duration:")
                .font(.system(size: 13, weight: .medium))

            Slider(
                value: Binding(
                    get: { step.delaySeconds },
                    set: { step.delaySeconds = (round($0 * 10) / 10) }
                ),
                in: 0.1...30.0
            )
            .frame(width: 180)

            TextField("Seconds", value: $step.delaySeconds, format: .number.precision(.fractionLength(2)))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .frame(width: 60)

            Text("seconds")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }
}
