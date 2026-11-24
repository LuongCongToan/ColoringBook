import AVFoundation

/// Short, friendly sounds for every action, synthesised at launch.
///
/// Children under five need to hear that something happened (Google,
/// "Designing engaging apps"). The sounds are generated in code rather than
/// shipped as files: no licences to check, nothing to download, a few
/// kilobytes of memory.
///
/// The session is `.ambient`: the ring/silent switch is respected, and a
/// parent's music keeps playing.
@MainActor
final class SoundFX {
    static let shared = SoundFX()

    enum Effect: CaseIterable {
        /// Paint bucket pour: a rising bloop.
        case fill
        /// Choosing a tool, color or size: a soft tick.
        case tap
        /// A sticker lands on the page: a little sparkle.
        case sticker
        /// A sticker is removed: a falling whoop.
        case remove
        /// Undo: a quick rewind.
        case undo
        /// Zoom in and out: a short rise or fall.
        case zoomIn, zoomOut
        /// Finger down with a brush: a light dab.
        case brush
    }

    /// Off switch for a parents' setting later.
    var isEnabled = true

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var next = 0
    private var buffers: [Effect: AVAudioPCMBuffer] = [:]
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        // A few voices, so quick taps can overlap instead of cutting off.
        for _ in 0..<4 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
        engine.mainMixerNode.outputVolume = 0.6
        for effect in Effect.allCases { buffers[effect] = render(effect) }
    }

    func play(_ effect: Effect) {
        guard isEnabled, let buffer = buffers[effect] else { return }
        if !engine.isRunning {
            do { try engine.start() } catch { return }
        }
        let player = players[next]
        next = (next + 1) % players.count
        player.stop()
        player.scheduleBuffer(buffer, at: nil)
        player.play()
    }

    // MARK: - Synthesis

    /// A tone that glides from one pitch to another under a pluck-shaped
    /// envelope, with a touch of second harmonic for warmth.
    private struct Note {
        var start: Double
        var duration: Double
        var from: Double
        var to: Double
        var volume: Double = 0.5
    }

    private func notes(for effect: Effect) -> [Note] {
        switch effect {
        case .fill:
            return [Note(start: 0, duration: 0.18, from: 320, to: 760, volume: 0.55),
                    Note(start: 0.06, duration: 0.14, from: 640, to: 1100, volume: 0.25)]
        case .tap:
            return [Note(start: 0, duration: 0.05, from: 1300, to: 1100, volume: 0.3)]
        case .sticker:
            // C6, E6, G6, C7: a bright little arpeggio.
            return [1047, 1319, 1568, 2093].enumerated().map { i, f in
                Note(start: Double(i) * 0.055, duration: 0.12, from: f, to: f * 1.01, volume: 0.32)
            }
        case .remove:
            return [Note(start: 0, duration: 0.2, from: 700, to: 220, volume: 0.45)]
        case .undo:
            return [Note(start: 0, duration: 0.08, from: 900, to: 600, volume: 0.35),
                    Note(start: 0.07, duration: 0.1, from: 650, to: 380, volume: 0.35)]
        case .zoomIn:
            return [Note(start: 0, duration: 0.14, from: 450, to: 900, volume: 0.3)]
        case .zoomOut:
            return [Note(start: 0, duration: 0.14, from: 900, to: 450, volume: 0.3)]
        case .brush:
            return [Note(start: 0, duration: 0.06, from: 520, to: 480, volume: 0.18)]
        }
    }

    private func render(_ effect: Effect) -> AVAudioPCMBuffer? {
        let list = notes(for: effect)
        let length = (list.map { $0.start + $0.duration }.max() ?? 0.1) + 0.02
        let rate = format.sampleRate
        let frames = AVAudioFrameCount(length * rate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let out = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        for i in 0..<Int(frames) { out[i] = 0 }

        for note in list {
            let first = Int(note.start * rate)
            let count = Int(note.duration * rate)
            var phase = 0.0
            for n in 0..<count where first + n < Int(frames) {
                let t = Double(n) / Double(count)
                let freq = note.from * pow(note.to / note.from, t)  // exponential glide
                phase += 2 * .pi * freq / rate
                // Fast attack, smooth decay: no clicks at either end.
                let attack = min(1, Double(n) / (0.004 * rate))
                let envelope = attack * pow(1 - t, 2.2)
                let sample = sin(phase) + 0.25 * sin(2 * phase)
                out[first + n] += Float(sample * envelope * note.volume * 0.8)
            }
        }
        // Keep the sum of overlapping notes out of clipping.
        for i in 0..<Int(frames) { out[i] = max(-1, min(1, out[i])) }
        return buffer
    }
}
