import AVFoundation
import ConfettiSwiftUI
import SwiftUI

struct LaunchEffectsView: View {
    @AppStorage("launchConfetti") private var confettiEnabled = true
    @AppStorage("launchSounds") private var soundsEnabled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var trigger = 0
    @State private var didCelebrate = false
    @State private var amount = Int.random(in: 20...100)
    @State private var repetitions = Int.random(in: 1...3)

    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .frame(width: 1, height: 1)
                .confettiCannon(
                    trigger: $trigger,
                    num: amount,
                    colors: [
                        LaunchAppearance.color("confetti1", fallback: .red),
                        LaunchAppearance.color("confetti2", fallback: .blue),
                        LaunchAppearance.color("confetti3", fallback: .orange),
                        LaunchAppearance.color("confetti4", fallback: .purple)
                    ],
                    confettiSize: 9,
                    rainHeight: geometry.size.height,
                    openingAngle: .degrees(45),
                    closingAngle: .degrees(135),
                    radius: min(geometry.size.width, 350),
                    repetitions: repetitions,
                    repetitionInterval: 0.35,
                    hapticFeedback: false
                )
                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.65)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            guard !didCelebrate else { return }
            didCelebrate = true
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            if confettiEnabled && !reduceMotion { trigger += 1 }
            if soundsEnabled { LaunchSound.play() }
        }
    }
}

@MainActor
enum LaunchSound {
    private static var player: AVAudioPlayer?

    @discardableResult
    static func play() -> String? {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            let notes = [[523.25, 659.25, 783.99], [587.33, 739.99, 880], [659.25, 783.99, 987.77]].randomElement()!
            player = try AVAudioPlayer(data: chime(notes: notes))
            player?.volume = 0.7
            player?.prepareToPlay()
            guard player?.play() == true else { return "Audio playback could not start. Try again." }
            return nil
        } catch {
            return "Couldn’t play the chime: \(error.localizedDescription)"
        }
    }

    private static func chime(notes: [Double]) -> Data {
        let sampleRate = 22050
        let duration = 0.45
        let sampleCount = Int(Double(sampleRate) * duration)
        var samples = Data(capacity: sampleCount * 2)
        for index in 0..<sampleCount {
            let time = Double(index) / Double(sampleRate)
            var signal = 0.0
            for (noteIndex, frequency) in notes.enumerated() {
                let localTime = time - Double(noteIndex) * 0.08
                if localTime >= 0 {
                    let envelope = min(localTime / 0.008, 1) * exp(-localTime * 12)
                    signal += sin(2 * .pi * frequency * localTime) * envelope / 3
                }
            }
            var sample = Int16(max(-1, min(1, signal)) * 24000).littleEndian
            withUnsafeBytes(of: &sample) { samples.append(contentsOf: $0) }
        }
        var result = Data()
        func text(_ value: String) { result.append(contentsOf: value.utf8) }
        func integer<T: FixedWidthInteger>(_ value: T) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { result.append(contentsOf: $0) }
        }
        text("RIFF"); integer(UInt32(36 + samples.count)); text("WAVE")
        text("fmt "); integer(UInt32(16)); integer(UInt16(1)); integer(UInt16(1))
        integer(UInt32(sampleRate)); integer(UInt32(sampleRate * 2)); integer(UInt16(2)); integer(UInt16(16))
        text("data"); integer(UInt32(samples.count)); result.append(samples)
        return result
    }
}
