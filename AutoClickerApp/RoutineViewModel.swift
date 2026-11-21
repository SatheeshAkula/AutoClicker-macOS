import Foundation
import AppKit
import UniformTypeIdentifiers

public class RoutineViewModel: ObservableObject {
    @Published public var steps: [RoutineStep] = RoutineStep.defaultFiveSteps()
    @Published public var settings: RoutineSettings = RoutineSettings()
    @Published public var alertMessage: String = ""
    @Published public var showSaveAlert: Bool = false

    public init() {}

    public func addStep() {
        steps.append(RoutineStep(kind: .keystroke, keyText: "down"))
    }

    public func duplicateStep(at index: Int) {
        var copy = steps[index]
        copy.id = UUID()
        steps.insert(copy, at: index + 1)
    }

    public func deleteStep(at index: Int) {
        if steps.count > 1 {
            steps.remove(at: index)
        }
    }

    public func moveStep(from source: Int, to destination: Int) {
        guard destination >= 0 && destination < steps.count else { return }
        let item = steps.remove(at: source)
        steps.insert(item, at: destination)
    }

    public func resetToDefault() {
        steps = RoutineStep.defaultFiveSteps()
        settings = RoutineSettings()
    }

    public func saveRoutineToFile() {
        let profile = RoutineProfile(name: "AutoClicker Profile", settings: settings, steps: steps)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.json]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.nameFieldStringValue = "routine.json"

        savePanel.begin { [weak self] response in
            guard let self = self else { return }
            if response == .OK, let url = savePanel.url {
                do {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    let data = try encoder.encode(profile)
                    try data.write(to: url)
                    DispatchQueue.main.async {
                        self.alertMessage = "Routine saved successfully!"
                        self.showSaveAlert = true
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.alertMessage = "Failed to save: \(error.localizedDescription)"
                        self.showSaveAlert = true
                    }
                }
            }
        }
    }

    public func loadRoutineFromFile() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [UTType.json]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false

        openPanel.begin { [weak self] response in
            guard let self = self else { return }
            if response == .OK, let url = openPanel.url {
                do {
                    let data = try Data(contentsOf: url)
                    let decoder = JSONDecoder()
                    let profile = try decoder.decode(RoutineProfile.self, from: data)
                    DispatchQueue.main.async {
                        self.steps = profile.steps
                        self.settings = profile.settings
                        self.alertMessage = "Routine loaded successfully! (\(profile.steps.count) steps)"
                        self.showSaveAlert = true
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.alertMessage = "Failed to load profile: \(error.localizedDescription)"
                        self.showSaveAlert = true
                    }
                }
            }
        }
    }
}
