import SwiftUI
import AppKit

public struct ContentView: View {
    @StateObject private var vm = RoutineViewModel()
    @StateObject private var runner = RoutineRunner.shared
    @StateObject private var picker = CoordinatePickerManager.shared

    public var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider()

            stepsList

            Divider()

            bottomControls

            Divider()

            footerBar
        }
        .frame(minWidth: 670, idealWidth: 690, minHeight: 520, idealHeight: 580)
        .alert(isPresented: $vm.showSaveAlert) {
            Alert(title: Text("AutoClicker"), message: Text(vm.alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Image(systemName: "cursorarrow.motionlines")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.accentColor)
                    Text("AutoClicker Workflow")
                        .font(.system(size: 15, weight: .bold))
                }

                HStack(spacing: 7) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(runner.statusMessage)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if runner.isExecuting {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Cycle: \(runner.currentCycle)" + (vm.settings.isInfiniteRepeat ? " (Infinite)" : " / \(vm.settings.repeatCount)"))
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundColor(.accentColor)
                    Text("Press ESC to Stop")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(.red)
                }

                Button(action: {
                    runner.stopRoutine()
                }) {
                    Label("STOP (ESC)", systemImage: "stop.circle.fill")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.red)
                        .cornerRadius(7)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            } else {
                Button(action: {
                    runner.startRoutine(settings: vm.settings, steps: vm.steps)
                }) {
                    Label("Start Routine (F6)", systemImage: "play.circle.fill")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.green)
                        .cornerRadius(7)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var statusColor: Color {
        if runner.isCountingDown { return .orange }
        if runner.isExecuting { return .green }
        return .secondary
    }

    // MARK: - Steps Canvas
    private var stepsList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(Array(vm.steps.enumerated()), id: \.element.id) { index, _ in
                    StepRowView(
                        step: $vm.steps[index],
                        index: index,
                        isCurrentStep: runner.currentStepIndex == index,
                        totalSteps: vm.steps.count,
                        onMoveUp: { vm.moveStep(from: index, to: index - 1) },
                        onMoveDown: { vm.moveStep(from: index, to: index + 1) },
                        onDuplicate: { vm.duplicateStep(at: index) },
                        onDelete: { vm.deleteStep(at: index) }
                    )
                }

                HStack(spacing: 14) {
                    Button(action: { vm.addStep() }) {
                        Label("Add Step", systemImage: "plus.circle.fill")
                            .font(.system(size: 13.5, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: { vm.resetToDefault() }) {
                        Label("Reset 5 Steps", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 13, weight: .regular))
                            .padding(.vertical, 7)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 6)
                .padding(.bottom, 10)
            }
            .padding(12)
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
    }

    // MARK: - Bottom Settings
    private var bottomControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 28) {
                // Universal Step Delay
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Universal Step Delay:")
                            .font(.system(size: 13, weight: .medium))
                        Text(String(format: "%.2f s", vm.settings.universalStepDelay))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.accentColor)
                    }
                    Slider(
                        value: Binding(
                            get: { vm.settings.universalStepDelay },
                            set: { vm.settings.universalStepDelay = (round($0 * 20) / 20) }
                        ),
                        in: 0.0...5.0
                    )
                    .frame(width: 180)
                }

                // Countdown delay
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Start Countdown:")
                            .font(.system(size: 13, weight: .medium))
                        Text(String(format: "%.1f s", vm.settings.initialCountdown))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.accentColor)
                    }
                    Slider(
                        value: Binding(
                            get: { vm.settings.initialCountdown },
                            set: { vm.settings.initialCountdown = (round($0 * 2) / 2) }
                        ),
                        in: 0.0...10.0
                    )
                    .frame(width: 160)
                }

                Spacer()
            }

            HStack(spacing: 18) {
                // Repeat Mode
                HStack(spacing: 8) {
                    Text("Repeat:")
                        .font(.system(size: 13, weight: .medium))

                    Picker("", selection: $vm.settings.isInfiniteRepeat) {
                        Text("Until ESC").tag(true)
                        Text("Fixed Count").tag(false)
                    }
                    .pickerStyle(.radioGroup)
                    .horizontalRadioGroupLayout()
                    .font(.system(size: 13))

                    if !vm.settings.isInfiniteRepeat {
                        Stepper(value: $vm.settings.repeatCount, in: 1...9999) {
                            Text("\(vm.settings.repeatCount) cycles")
                                .font(.system(size: 13, weight: .bold))
                        }
                    }
                }

                Spacer()

                // Profiles
                HStack(spacing: 10) {
                    Button("Save Routine...") {
                        vm.saveRoutineToFile()
                    }
                    .font(.system(size: 13, weight: .regular))
                    .buttonStyle(.bordered)

                    Button("Load Routine...") {
                        vm.loadRoutineFromFile()
                    }
                    .font(.system(size: 13, weight: .regular))
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Footer Bar
    private var footerBar: some View {
        HStack {
            Spacer()
            Text("Designed by Satheesh Akula")
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundColor(.secondary.opacity(0.9))
            Spacer()
        }
        .padding(.vertical, 6)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
