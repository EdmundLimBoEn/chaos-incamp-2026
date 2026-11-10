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
        if defaults.string(forKey: "appearanceTheme") == "saved" && mode != "crazy" && mode != "interactive" && !(mode == "subtle" && role == "accent"),
           let saved = defaults.dictionary(forKey: "savedThemePalette"), let rgb = saved[role] as? [Double], rgb.count == 3 {
            return Color(red: rgb[0], green: rgb[1], blue: rgb[2])
        }
        if defaults.string(forKey: "appearanceTheme") == "lagoon" && mode != "crazy" && mode != "interactive" && !(mode == "subtle" && role == "accent") {
            switch role {
            case "background": return Color(red: 0.259, green: 0.435, blue: 0.455)
            case "surface": return Color(red: 0.20, green: 0.37, blue: 0.39)
            case "foreground": return Color(red: 0.89, green: 0.94, blue: 0.95)
            case "secondary": return Color(red: 0.72, green: 0.86, blue: 0.86)
            case "accent": return Color(red: 0.16, green: 0.79, blue: 0.62)
            default: break
            }
        }
        guard mode == "crazy" || mode == "interactive" || (mode == "subtle" && role == "accent"),
              let components = defaults.array(forKey: "launchPalette." + role) as? [Double], components.count == 3 else { return fallback }
        return Color(red: components[0], green: components[1], blue: components[2])
    }

    static func saveCurrentTheme(isLight: Bool = false) {
        let current = palette
        let fallbacks: [String: Color] = ["background": current.background, "foreground": current.foreground, "accent": current.accent, "secondary": current.secondary, "surface": current.surface, "danger": current.danger, "teal": .teal, "blue": .blue, "orange": .orange, "purple": .purple, "pink": .pink, "confetti1": .red, "confetti2": .blue, "confetti3": .orange, "confetti4": .purple]
        let style: UIUserInterfaceStyle = isLight ? .light : .dark
        let traits = UITraitCollection(userInterfaceStyle: style)
        var saved: [String: [Double]] = [:]
        for role in roles {
            let uiColor = UIColor(color(role, fallback: fallbacks[role] ?? .white)).resolvedColor(with: traits)
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
                saved[role] = [Double(red), Double(green), Double(blue)]
            }
        }
        applyTheme(name: "Saved theme", colors: saved, isLight: isLight)
    }

    static func applyTheme(name: String, colors: [String: [Double]], isLight: Bool) {
        let defaults = UserDefaults.standard
        var saved: [String: [Double]] = [
            "danger": [1, 0.23, 0.27], "teal": [0.1, 0.72, 0.68],
            "blue": [0.2, 0.5, 0.98], "orange": [1, 0.55, 0.12],
            "purple": [0.65, 0.35, 0.95], "pink": [0.92, 0.32, 0.62]
        ]
        for (role, rgb) in colors where roles.contains(role) && rgb.count == 3 && rgb.allSatisfy(\.isFinite) {
            saved[role] = rgb.map { min(1, max(0, $0)) }
        }
        for (index, role) in ["accent", "teal", "orange", "purple"].enumerated() {
            if saved["confetti\(index + 1)"] == nil { saved["confetti\(index + 1)"] = saved[role] }
        }
        let title = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        defaults.set(title.isEmpty ? "Saved theme" : title, forKey: "savedThemeName")
        defaults.set(saved, forKey: "savedThemePalette")
        defaults.set(true, forKey: "hasSavedTheme")
        defaults.set(isLight ? "light" : "dark", forKey: "savedThemeScheme")
        defaults.set("normal", forKey: "randomnessMode")
        defaults.set("saved", forKey: "appearanceTheme")
        defaults.set(defaults.integer(forKey: "paletteRevision") + 1, forKey: "paletteRevision")
    }

    static var accentForeground: Color {
        let accent = CalendarAppearance.accent(UserDefaults.standard.string(forKey: "accentColor") ?? "red")
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(accent).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func linear(_ value: CGFloat) -> Double {
            let value = Double(value)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        return luminance > 0.179 ? .black : .white
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


private struct CalendarThemeModifier: ViewModifier {
    @AppStorage("paletteRevision") private var revision = 0
    @AppStorage("appearanceTheme") private var theme = "dark"
    @AppStorage("accentColor") private var accent = "red"
    @AppStorage("randomnessMode") private var randomness = "normal"
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(LaunchAppearance.palette.background)
            .foregroundStyle(LaunchAppearance.palette.foreground)
            .tint(LaunchAppearance.palette.accent)
            .toolbarBackground(LaunchAppearance.palette.background, for: .navigationBar, .tabBar)
            .toolbarBackground(.visible, for: .navigationBar, .tabBar)
            .preferredColorScheme(CalendarAppearance.scheme(theme))
    }
}

extension View {
    func calendarTheme() -> some View { modifier(CalendarThemeModifier()) }
}
