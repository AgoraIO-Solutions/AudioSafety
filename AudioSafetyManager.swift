import Foundation
import AgoraRtcKit

/// Manages rolling audio buffers for remote users and the local user, and generates WAV reports.
class AudioSafetyManager: NSObject {
    
    private let bufferDurationSeconds: Int
    private let queue = DispatchQueue(label: "io.agora.moderation.safetyQueue", qos: .userInitiated)
    
    private var userBuffers: [UInt: RollingBuffer] = [:]
    private var localUserBuffer: RollingBuffer?
    private weak var agoraKit: AgoraRtcEngineKit?
    
    // Recording state management
    private var isRecording: Bool = false
    
    // User registration system - only track registered users
    private var registeredUsers: Set<UInt> = []
    
    weak var forwardingDelegate: AgoraAudioFrameDelegate?
    
    var localUserReportingUid: UInt? 
    
    init(agoraKit: AgoraRtcEngineKit, bufferDurationSeconds: Int = 300, enableRegisterLocal: Bool = true) {
        self.agoraKit = agoraKit
        self.bufferDurationSeconds = bufferDurationSeconds
        super.init()
        
        agoraKit.setAudioFrameDelegate(self)
        
        agoraKit.setPlaybackAudioFrameBeforeMixingParameters(48000, channel: 1)
        
        agoraKit.setRecordingAudioFrameParameters(48000, channel: 1, mode: .readonly, samplesPerCall: 1024)
        
        print("[AudioSafetyManager] Initialized with buffer duration: \(bufferDurationSeconds)s")
    }
    
    func recordBuffer(uid: UInt, completion: @escaping (URL?) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                completion(nil)
                return
            }
            
            guard let buffer = self.userBuffers[uid] else {
                print("[AudioSafetyManager] No remote buffer found for user \(uid)")
                completion(nil)
                return
            }
            
            do {
                let fileUrl = try buffer.saveToWav(uid: uid)
                completion(fileUrl)
            } catch {
                print("[AudioSafetyManager] Failed to write WAV: \(error)")
                completion(nil)
            }
        }
    }
    
    func recordLocalBuffer(completion: @escaping (URL?) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                completion(nil)
                return
            }
            
            let uidForFile = self.localUserReportingUid ?? 0
            
            guard let buffer = self.localUserBuffer else {
                print("[AudioSafetyManager] Local buffer not found (microphone may be muted or not started).")
                completion(nil)
                return
            }
            
            do {
                let fileUrl = try buffer.saveToWav(uid: uidForFile)
                completion(fileUrl)
            } catch {
                print("[AudioSafetyManager] Failed to write local WAV: \(error)")
                completion(nil)
            }
        }
    }
    
    /// Register a user ID to start monitoring their audio
    func registerUser(uid: UInt) {
        queue.async { [weak self] in
            self?.registeredUsers.insert(uid)
            print("[AudioSafetyManager] Registered user \(uid) for audio monitoring")
        }
    }
    
    /// Unregister a user ID to stop monitoring their audio
    func unregisterUser(uid: UInt) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.registeredUsers.remove(uid)
            self.userBuffers.removeValue(forKey: uid)
            print("[AudioSafetyManager] Unregistered user \(uid) from audio monitoring")
        }
    }
    
    /// Start recording (called when joining channel)
    func startRecording() {
        queue.async { [weak self] in
            self?.isRecording = true
            print("[AudioSafetyManager] Recording started")
        }
    }
    
    /// Stop recording and cleanup
    func stopRecording() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.isRecording = false
            self.userBuffers.removeAll()
            self.registeredUsers.removeAll()
            print("[AudioSafetyManager] Recording stopped")
        }
    }
    
    func cleanup() {
        stopRecording()
        agoraKit?.setAudioFrameDelegate(nil)
        queue.sync {
            localUserBuffer = nil
        }
        print("[AudioSafetyManager] Cleanup completed")
    }
}

extension AudioSafetyManager: AgoraAudioFrameDelegate {
    
    // MARK: - Audio Params Configuration
    
    func getRecordAudioParams() -> AgoraAudioParams {
        let params = AgoraAudioParams()
        params.sampleRate = 48000
        params.channel = 1
        params.mode = .readOnly
        params.samplesPerCall = 1024
        return params
    }
    
    func getPlaybackAudioParams() -> AgoraAudioParams {
        let params = AgoraAudioParams()
        params.sampleRate = 48000
        params.channel = 1
        params.mode = .readOnly
        params.samplesPerCall = 1024
        return params
    }
    
    func getMixedAudioParams() -> AgoraAudioParams {
        return AgoraAudioParams()
    }
    
    func getEarMonitoringAudioParams() -> AgoraAudioParams {
        return AgoraAudioParams()
    }
    
    func getObservedAudioFramePosition() -> AgoraAudioFramePosition {
        // Observe both record and playback before mixing
        return [.record, .playbackBeforeMixing]
    }
    
    // MARK: - Audio Frame Callbacks
    
    func onPlaybackAudioFrame(beforeMixing frame: AgoraAudioFrame, channelId: String, uid: UInt) -> Bool {
        
        // Early return checks to avoid unnecessary operations
        guard isRecording else { return forwardingDelegate?.onPlaybackAudioFrame?(beforeMixing: frame, channelId: channelId, uid: uid) ?? true }
        guard registeredUsers.contains(uid) else { return forwardingDelegate?.onPlaybackAudioFrame?(beforeMixing: frame, channelId: channelId, uid: uid) ?? true }
        guard let rawBuffer = frame.buffer else { return forwardingDelegate?.onPlaybackAudioFrame?(beforeMixing: frame, channelId: channelId, uid: uid) ?? true }
        
        let samplesPerSec = Int(frame.samplesPerSec)
        let channels = Int(frame.channels)
        let bytesPerSample = Int(frame.bytesPerSample)
        let samples = Int(frame.samples)
        
        // Validate audio format (48kHz, Mono, 16-bit)
        guard samplesPerSec == 48000, channels == 1, bytesPerSample == 2 else {
            return forwardingDelegate?.onPlaybackAudioFrame?(beforeMixing: frame, channelId: channelId, uid: uid) ?? true
        }
        
        let size = samples * channels * bytesPerSample
        let dataCopy = Data(bytes: rawBuffer, count: size)
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Get or create buffer dynamically (no hard limit)
            if self.userBuffers[uid] == nil {
                self.userBuffers[uid] = RollingBuffer(
                    duration: self.bufferDurationSeconds,
                    sampleRate: samplesPerSec,
                    channels: channels
                )
            }
            
            self.userBuffers[uid]?.push(data: dataCopy)
        }
        
        return forwardingDelegate?.onPlaybackAudioFrame?(beforeMixing: frame, channelId: channelId, uid: uid) ?? true
    }
    
    func onRecordAudioFrame(_ frame: AgoraAudioFrame, channelId: String) -> Bool {
        
        // Early return checks to avoid unnecessary operations
        guard isRecording else { return forwardingDelegate?.onRecordAudioFrame?(frame, channelId: channelId) ?? true }
        guard let localUid = localUserReportingUid, localUid != 0 else { return forwardingDelegate?.onRecordAudioFrame?(frame, channelId: channelId) ?? true }
        guard registeredUsers.contains(localUid) else { return forwardingDelegate?.onRecordAudioFrame?(frame, channelId: channelId) ?? true }
        guard let rawBuffer = frame.buffer else { return forwardingDelegate?.onRecordAudioFrame?(frame, channelId: channelId) ?? true }
        
        let samplesPerSec = Int(frame.samplesPerSec)
        let channels = Int(frame.channels)
        let bytesPerSample = Int(frame.bytesPerSample)
        let samples = Int(frame.samples)
        
        // Validate audio format (48kHz, Mono, 16-bit)
        guard samplesPerSec == 48000, channels == 1, bytesPerSample == 2 else {
            return forwardingDelegate?.onRecordAudioFrame?(frame, channelId: channelId) ?? true
        }
        
        let size = samples * channels * bytesPerSample
        let dataCopy = Data(bytes: rawBuffer, count: size)
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            if self.localUserBuffer == nil {
                self.localUserBuffer = RollingBuffer(
                    duration: self.bufferDurationSeconds,
                    sampleRate: samplesPerSec,
                    channels: channels
                )
            }
            
            self.localUserBuffer?.push(data: dataCopy)
        }
        
        return forwardingDelegate?.onRecordAudioFrame?(frame, channelId: channelId) ?? true
    }
    
    func onPlaybackAudioFrame(_ frame: AgoraAudioFrame, channelId: String) -> Bool {
        return forwardingDelegate?.onPlaybackAudioFrame?(frame, channelId: channelId) ?? true
    }
    
    func onMixedAudioFrame(_ frame: AgoraAudioFrame, channelId: String) -> Bool {
        return forwardingDelegate?.onMixedAudioFrame?(frame, channelId: channelId) ?? true
    }
    
    func onEarMonitoringAudioFrame(_ frame: AgoraAudioFrame) -> Bool {
        return forwardingDelegate?.onEarMonitoringAudioFrame?(frame) ?? true
    }
    
    // Legacy callback - maintained for compatibility
    func onRecord(_ frame: AgoraAudioFrame, channelId: String) -> Bool {
        return true
    }
}

private class RollingBuffer {
    private var buffer: UnsafeMutableRawPointer
    private var capacity: Int
    private var head: Int = 0
    private var isFull: Bool = false
    
    let sampleRate: Int
    let channels: Int
    
    init(duration: Int, sampleRate: Int, channels: Int) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.capacity = duration * sampleRate * channels * 2
        self.buffer = UnsafeMutableRawPointer.allocate(byteCount: capacity, alignment: 1)
    }
    
    deinit {
        buffer.deallocate()
    }
    
    func push(data: Data) {
        let size = data.count
        if size > capacity { return }
        
        data.withUnsafeBytes { rawBufferPointer in
            guard let rawPtr = rawBufferPointer.baseAddress else { return }
            
            let firstChunk = min(size, capacity - head)
            
            buffer.advanced(by: head).copyMemory(from: rawPtr, byteCount: firstChunk)
            
            if size > firstChunk {
                buffer.copyMemory(from: rawPtr.advanced(by: firstChunk), byteCount: size - firstChunk)
            }
            
            head = (head + size) % capacity
            if head == 0 || head < size { isFull = true }
        }
    }
    
    func saveToWav(uid: UInt) throws -> URL {
        let fileName = "report_uid_\(uid)_\(Int(Date().timeIntervalSince1970)).wav"
        let fileUrl = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        let currentSize = isFull ? capacity : head
        var fileData = Data()
        
        fileData.append(createWavHeader(dataSize: currentSize))
        
        if isFull {
            let part1Size = capacity - head
            let part1Data = Data(bytes: buffer.advanced(by: head), count: part1Size)
            fileData.append(part1Data)
            
            let part2Data = Data(bytes: buffer, count: head)
            fileData.append(part2Data)
        } else {
            let data = Data(bytes: buffer, count: head)
            fileData.append(data)
        }
        
        try fileData.write(to: fileUrl)
        return fileUrl
    }
    
    private func createWavHeader(dataSize: Int) -> Data {
        var header = Data()
        let longSampleRate = Int32(sampleRate)
        let channels16 = Int16(channels)
        let bitsPerSample = Int16(16)
        let byteRate = Int32(sampleRate * channels * 2)
        let blockAlign = Int16(channels * 2)
        let totalFileSize = Int32(36 + dataSize)
        
        func append<T>(_ value: T) {
            var val = value
            withUnsafeBytes(of: &val) { header.append(contentsOf: $0) }
        }
        
        header.append("RIFF".data(using: .ascii)!)
        append(totalFileSize.littleEndian)
        header.append("WAVE".data(using: .ascii)!)
        header.append("fmt ".data(using: .ascii)!)
        
        append(Int32(16).littleEndian)
        append(Int16(1).littleEndian)
        append(channels16.littleEndian)
        append(longSampleRate.littleEndian)
        append(byteRate.littleEndian)
        append(blockAlign.littleEndian)
        append(bitsPerSample.littleEndian)
        
        header.append("data".data(using: .ascii)!)
        append(Int32(dataSize).littleEndian)
        
        return header
    }
}