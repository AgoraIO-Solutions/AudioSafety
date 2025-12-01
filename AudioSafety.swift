import UIKit
import AgoraRtcKit

/// This ViewController demonstrates how to use the AudioSafetyManager, supporting both local and remote reporting.
class AudioSafety: UIViewController {
    
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Waiting to join channel..."
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 14)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var instructionLabel: UILabel = {
        let label = UILabel()
        label.text = "Tap on any user seat to report"
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 12)
        label.textColor = .systemGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Audio seat views (8 seats to display users)
    private var audioSeats: [AudioSeatView] = []
    private var seatUserMapping: [UInt: AudioSeatView] = [:] // uid -> seat
    
    private var agoraKit: AgoraRtcEngineKit!
    private var safetyManager: AudioSafetyManager?
    private var localUid: UInt = 0
    
    // Debounce for reportUser to prevent rapid consecutive calls
    private var lastReportTime: TimeInterval = 0
    private let reportDebounceInterval: TimeInterval = 1.0

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Audio Safety Demo"
        view.backgroundColor = .systemBackground
        setupUI()
        initializeAgoraEngine()
        joinChannel()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        leaveChannel()
        AgoraRtcEngineKit.destroy()
    }
    
    private func initializeAgoraEngine() {
        let config = AgoraRtcEngineConfig()
        config.appId = KeyStore.appId
        
        agoraKit = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        
        safetyManager = AudioSafetyManager(agoraKit: agoraKit, bufferDurationSeconds: 300)
        safetyManager?.forwardingDelegate = self
    }
    
    private func joinChannel() {
        agoraKit.enableAudio()
        agoraKit.setClientRole(.broadcaster)
        
        let option = AgoraRtcChannelMediaOptions()
        option.autoSubscribeAudio = true
        option.publishMicrophoneTrack = true
        
        let result = agoraKit.joinChannel(byToken: KeyStore.token, channelId: KeyStore.channelName, uid: 0, mediaOptions: option)
        if result != 0 {
            statusLabel.text = "Join failed: \(result)"
        }
    }
    
    private func leaveChannel() {
        safetyManager?.stopRecording()
        safetyManager?.cleanup()
        safetyManager = nil
        agoraKit.leaveChannel(nil)
    }
    
    @objc private func handleSeatTapped(_ gesture: UITapGestureRecognizer) {
        guard let seat = gesture.view as? AudioSeatView else { return }
        guard let uid = seat.uid else {
            statusLabel.text = "No user in this seat"
            return
        }
        
        // Debounce: prevent rapid consecutive reports
        let currentTime = Date().timeIntervalSince1970
        if currentTime - lastReportTime < reportDebounceInterval {
            statusLabel.text = "Please wait before reporting again"
            return
        }
        lastReportTime = currentTime
        
        reportUser(uid: uid)
    }
    
    private func reportUser(uid: UInt) {
        guard let manager = safetyManager else {
            statusLabel.text = "Safety manager not available"
            return
        }
        
        statusLabel.text = "Generating audio evidence for user \(uid)..."
        
        // Report the specified user's audio buffer
        manager.recordBuffer(uid: uid) { [weak self] fileUrl in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let url = fileUrl {
                    self.statusLabel.text = "Audio evidence saved for user \(uid)\n\(url.lastPathComponent)"
                    print("[AudioSafety] Reported user \(uid), WAV file: \(url.path)")
                    // In production, upload to your moderation service
                    self.shareFiles(urls: [url])
                } else {
                    self.statusLabel.text = "Failed to generate report for user \(uid)"
                    print("[AudioSafety] Failed to report user \(uid)")
                }
            }
        }
    }
    
    private func shareFiles(urls: [URL]) {
        let activityVC = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        present(activityVC, animated: true)
    }
    
    private func setupUI() {
        view.addSubview(statusLabel)
        view.addSubview(instructionLabel)
        
        // Create 8 audio seats (2 rows of 4)
        let seatSize: CGFloat = 80
        let spacing: CGFloat = 12
        
        for i in 0..<8 {
            let seat = AudioSeatView()
            seat.translatesAutoresizingMaskIntoConstraints = false
            seat.isUserInteractionEnabled = true
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleSeatTapped(_:)))
            seat.addGestureRecognizer(tapGesture)
            view.addSubview(seat)
            audioSeats.append(seat)
            
            let row = i / 4
            let col = i % 4
            let topOffset: CGFloat = 120 + CGFloat(row) * (seatSize + spacing)
            let leadingOffset: CGFloat = 20 + CGFloat(col) * (seatSize + spacing)
            
            NSLayoutConstraint.activate([
                seat.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: topOffset),
                seat.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leadingOffset),
                seat.widthAnchor.constraint(equalToConstant: seatSize),
                seat.heightAnchor.constraint(equalToConstant: seatSize)
            ])
        }
        
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            instructionLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
}

extension AudioSafety: AgoraRtcEngineDelegate {
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        print("[AudioSafety] Joined channel '\(channel)' as UID \(uid)")
        
        localUid = uid
        safetyManager?.localUserReportingUid = uid
        
        // Start recording and register local user
        safetyManager?.startRecording()
        safetyManager?.registerUser(uid)
        
        // Find first available seat for local user
        if let emptySeat = audioSeats.first(where: { $0.uid == nil }) {
            emptySeat.configure(uid: uid, isLocal: true)
            seatUserMapping[uid] = emptySeat
        }
        
        statusLabel.text = "Joined '\(channel)' as UID \(uid)\nWaiting for remote users..."
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        print("[AudioSafety] User \(uid) joined")
        
        // Register remote user for audio monitoring
        safetyManager?.registerUser(uid)
        
        // Find first available seat for remote user
        if let emptySeat = audioSeats.first(where: { $0.uid == nil }) {
            emptySeat.configure(uid: uid, isLocal: false)
            seatUserMapping[uid] = emptySeat
        }
        
        statusLabel.text = "User \(uid) joined. Tap seats to report."
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        print("[AudioSafety] User \(uid) left (reason: \(reason.rawValue))")
        
        // Unregister user when they leave
        safetyManager?.unregisterUser(uid)
        
        // Clear the seat
        if let seat = seatUserMapping[uid] {
            seat.clear()
            seatUserMapping.removeValue(forKey: uid)
        }
        
        statusLabel.text = "User \(uid) left the channel"
    }
}

extension AudioSafety: AgoraAudioFrameDelegate {
    func onPlaybackAudioFrame(_ frame: AgoraAudioFrame, channelId: String) -> Bool {
        return true
    }
}

// MARK: - AudioSeatView (similar to Android's AudioOnlyLayout)

class AudioSeatView: UIView {
    
    private(set) var uid: UInt?
    private var isLocal: Bool = false
    
    private lazy var avatarView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray5
        view.layer.cornerRadius = 30
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var uidLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var roleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 10)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "Empty"
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 12)
        label.textColor = .systemGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .systemBackground
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemGray4.cgColor
        
        addSubview(avatarView)
        addSubview(uidLabel)
        addSubview(roleLabel)
        addSubview(emptyLabel)
        
        NSLayoutConstraint.activate([
            avatarView.centerXAnchor.constraint(equalTo: centerXAnchor),
            avatarView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            avatarView.widthAnchor.constraint(equalToConstant: 60),
            avatarView.heightAnchor.constraint(equalToConstant: 60),
            
            uidLabel.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 2),
            uidLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            uidLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            
            roleLabel.topAnchor.constraint(equalTo: uidLabel.bottomAnchor),
            roleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            roleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            
            emptyLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        showEmptyState()
    }
    
    func configure(uid: UInt, isLocal: Bool) {
        self.uid = uid
        self.isLocal = isLocal
        
        uidLabel.text = "\(uid)"
        roleLabel.text = isLocal ? "Local (You)" : "Remote"
        avatarView.backgroundColor = isLocal ? .systemBlue : .systemGreen
        layer.borderColor = isLocal ? UIColor.systemBlue.cgColor : UIColor.systemGreen.cgColor
        layer.borderWidth = 2
        
        uidLabel.isHidden = false
        roleLabel.isHidden = false
        avatarView.isHidden = false
        emptyLabel.isHidden = true
    }
    
    func clear() {
        self.uid = nil
        self.isLocal = false
        showEmptyState()
    }
    
    private func showEmptyState() {
        uidLabel.isHidden = true
        roleLabel.isHidden = true
        avatarView.isHidden = true
        emptyLabel.isHidden = false
        layer.borderColor = UIColor.systemGray4.cgColor
        layer.borderWidth = 1
    }
}