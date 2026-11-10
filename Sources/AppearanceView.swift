import SwiftUI

enum CalendarAppearance {
    static func accent(_ key: String) -> Color {
        switch key {
        case "teal": .teal
        case "blue": .blue
        case "purple": .purple
        case "orange": .orange
        default: .red
        }
    }

    static func scheme(_ key: String) -> ColorScheme? {
        switch key {
        case "light": .light
        case "system": nil
        default: .dark
        }
    }
}

struct AppearanceView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearanceTheme") private var theme = "dark"
    @AppStorage("accentColor") private var accent = "red"
    @AppStorage("compactCalendar") private var compact = false
    private let accents = ["red", "teal", "blue", "purple", "orange"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Theme") {
                    Picker("Appearance", selection: $theme) {
                        Text("Dark").tag("dark")
                        Text("Light").tag("light")
                        Text("System").tag("system")
                    }.pickerStyle(.segmented)
                }
                Section("Accent color") {
                    HStack(spacing: 20) {
                        ForEach(accents, id: \.self) { value in
                            Button { accent = value } label: {
                                Circle().fill(CalendarAppearance.accent(value))
                                    .frame(width: 34, height: 34)
                                    .overlay {
                                        if value == accent {
                                            Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(value.capitalized)
                            .accessibilityAddTraits(value == accent ? .isSelected : [])
                        }
                    }.padding(.vertical, 6)
                }
                Section("Calendar") {
                    Toggle("Compact month view", isOn: $compact)
                    Text("Show shorter day cells to fit more of the month on screen.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Preview") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Tuesday").font(.headline)
                            Spacer()
                            Text("10").font(.headline).foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(CalendarAppearance.accent(accent), in: Circle())
                        }
                        HStack(spacing: 9) {
                            RoundedRectangle(cornerRadius: 2).fill(CalendarAppearance.accent(accent)).frame(width: 3)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Make time for your next idea").font(.subheadline.bold())
                                Text("10:00 – 11:00").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(CalendarAppearance.accent(accent).opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                        .frame(height: compact ? 58 : 76)
                    }.padding(.vertical, 8)
                }
            }
            .navigationTitle("Appearance")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(CalendarAppearance.accent(accent))
        .preferredColorScheme(CalendarAppearance.scheme(theme))
    }
}
