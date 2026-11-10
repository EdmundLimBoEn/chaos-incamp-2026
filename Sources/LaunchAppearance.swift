import SwiftUI

enum LaunchAppearance {
    static let roles = ["background", "foreground", "accent", "secondary", "surface", "danger", "teal", "blue", "orange", "purple", "pink", "confetti1", "confetti2", "confetti3", "confetti4"]

    static func refreshForLaunch() {
        let defaults = UserDefaults.standard
        let mode = defaults.string(forKey: "randomnessMode") ?? "normal"
        if mode == "crazy" || mode == "interactive" {
            for role in roles {
                defaults.set((0..<3).map { _ in Double.random(in: 0...1) }, forKey: "launchPalette." + role)
            }
        } else if mode == "subtle" {
            let hues: [[Double]] = [[0.98, 0.27, 0.32], [0.1, 0.72, 0.68], [0.2, 0.5, 0.98], [0.65, 0.35, 0.95], [1, 0.55, 0.12], [0.92, 0.32, 0.62]]
            let previous = defaults.integer(forKey: "launchPalette.lastHue")
            let choices = hues.indices.filter { $0 != previous }
            let index = choices.randomElement() ?? 0
            defaults.set(index, forKey: "launchPalette.lastHue")
            defaults.set(hues[index], forKey: "launchPalette.accent")
        }
        defaults.set(defaults.integer(forKey: "paletteRevision") + 1, forKey: "paletteRevision")
    }

    static func color(_ role: String, fallback: Color) -> Color {
        let defaults = UserDefaults.standard
        let mode = defaults.string(forKey: "randomnessMode") ?? "normal"
        guard mode == "crazy" || mode == "interactive" || (mode == "subtle" && role == "accent"),
              let components = defaults.array(forKey: "launchPalette." + role) as? [Double], components.count == 3 else { return fallback }
        return Color(red: components[0], green: components[1], blue: components[2])
    }

    static var palette: LaunchPalette {
        LaunchPalette(
            background: color("background", fallback: Color(uiColor: .systemBackground)),
            foreground: color("foreground", fallback: .primary),
            accent: CalendarAppearance.accent(UserDefaults.standard.string(forKey: "accentColor") ?? "red"),
            secondary: color("secondary", fallback: .secondary),
            surface: color("surface", fallback: Color(uiColor: .secondarySystemBackground)),
            danger: color("danger", fallback: .red)
        )
    }
}

struct LaunchPalette {
    let background: Color
    let foreground: Color
    let accent: Color
    let secondary: Color
    let surface: Color
    let danger: Color
}


struct InteractionThemeObserver: UIViewRepresentable {
    func makeUIView(context: Context) -> ThemeInteractionSensor { ThemeInteractionSensor() }
    func updateUIView(_ uiView: ThemeInteractionSensor, context: Context) {}
}

final class ThemeInteractionSensor: UIView, UIGestureRecognizerDelegate {
    private weak var observedWindow: UIWindow?
    private var recognizers: [UIGestureRecognizer] = []

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window !== observedWindow else { return }
        for recognizer in recognizers { observedWindow?.removeGestureRecognizer(recognizer) }
        recognizers.removeAll()
        observedWindow = window
        guard let window else { return }
        let tap = UITapGestureRecognizer(target: self, action: #selector(interacted(_:)))
        let pan = UIPanGestureRecognizer(target: self, action: #selector(interacted(_:)))
        for recognizer in [tap as UIGestureRecognizer, pan] {
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            recognizer.delegate = self
            window.addGestureRecognizer(recognizer)
            recognizers.append(recognizer)
        }
    }

    @objc private func interacted(_ recognizer: UIGestureRecognizer) {
        guard recognizer.state == .ended,
              UserDefaults.standard.string(forKey: "randomnessMode") == "interactive" else { return }
        LaunchAppearance.refreshForLaunch()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
}
