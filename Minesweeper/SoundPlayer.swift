import AVFoundation

// 音效全部在程式裡即時合成，不需要額外的音檔
@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()

    enum Effect { case reveal, flag, explosion, win }

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var players: [AVAudioPlayerNode] = []
    private var next = 0
    private var buffers: [Effect: AVAudioPCMBuffer] = [:]

    private init() {
        // ambient：不會打斷其他 App 的音樂，手機切到靜音時也會跟著靜音
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)

        // 準備幾個播放器輪流用，連續點擊時聲音才不會互相打斷
        for _ in 0..<4 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
        buffers[.reveal] = makeBuffer(duration: 0.05) { t in
            sin(2 * .pi * 1400 * t) * exp(-t * 90) * 0.35
        }
        buffers[.flag] = makeBuffer(duration: 0.12) { t in
            let f = t < 0.05 ? 880.0 : 1320.0
            return sin(2 * .pi * f * t) * exp(-t * 25) * 0.3
        }
        buffers[.explosion] = makeExplosion()
        buffers[.win] = makeWin()
        try? engine.start()
    }

    func play(_ effect: Effect) {
        guard let buffer = buffers[effect] else { return }
        if !engine.isRunning {
            try? engine.start()
        }
        let p = players[next]
        next = (next + 1) % players.count
        p.stop()
        p.scheduleBuffer(buffer, at: nil)
        p.play()
    }

    private func makeBuffer(duration: Double, _ sample: (Double) -> Double) -> AVAudioPCMBuffer {
        let count = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count)!
        buffer.frameLength = count
        let data = buffer.floatChannelData![0]
        for n in 0..<Int(count) {
            data[n] = Float(sample(Double(n) / format.sampleRate))
        }
        return buffer
    }

    // 爆炸：低頻的轟聲 + 慢慢變悶的雜訊
    private func makeExplosion() -> AVAudioPCMBuffer {
        var low = 0.0
        var phase = 0.0
        return makeBuffer(duration: 1.6) { t in
            let noise = Double.random(in: -1...1)
            // 低通濾波：越後面越悶
            let cutoff = 0.5 * exp(-t * 2.5) + 0.02
            low += (noise - low) * cutoff
            let freq = 60 * exp(-t * 1.5) + 30
            phase += 2 * .pi * freq / 44_100
            let boom = sin(phase) * exp(-t * 3)
            let attack = min(t / 0.005, 1)
            return (low * 1.6 + boom * 0.8) * exp(-t * 2.2) * attack * 0.9
        }
    }

    // 勝利：往上走的四個音
    private func makeWin() -> AVAudioPCMBuffer {
        let notes = [523.25, 659.25, 783.99, 1046.5]
        let step = 0.11
        return makeBuffer(duration: step * Double(notes.count) + 0.3) { t in
            let k = min(Int(t / step), notes.count - 1)
            let local = t - Double(k) * step
            let square = sin(2 * .pi * notes[k] * t) > 0 ? 1.0 : -1.0
            return square * exp(-local * (k == notes.count - 1 ? 5 : 12)) * 0.12
        }
    }
}
