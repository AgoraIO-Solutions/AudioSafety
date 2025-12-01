# AudioSafety iOS Demo

This is an iOS implementation of the Audio Safety feature for real-time voice moderation, matching the Android reference implementation.

## Features

- ✅ Rolling audio buffer (300 seconds default) for local and remote users
- ✅ 8-seat audio view displaying joined users
- ✅ Tap-to-report functionality for any user
- ✅ WAV file generation with complete audio evidence
- ✅ User registration system for selective monitoring
- ✅ Thread-safe audio processing
- ✅ Debounce protection for report actions

## Requirements

- iOS 13.0+
- Xcode 14.0+
- CocoaPods
- Agora App ID

## Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/AgoraIO-Solutions/AudioSafety.git
cd AudioSafety
```

### 2. Install CocoaPods Dependencies

```bash
pod install
```

### 3. Configure Your Agora Credentials

Copy the example credentials file and add your Agora App ID:

```bash
cp KeyStore.swift.example KeyStore.swift
```

Then open `KeyStore.swift` and replace the placeholder values:

```swift
struct KeyStore {
    static let appId: String = "YOUR_AGORA_APP_ID"  // Get from https://console.agora.io/
    static let token: String? = nil                  // Optional: Add token for production
    static let channelName: String = "test-channel"  // Change as needed
}
```

⚠️ **Important**: `KeyStore.swift` is in `.gitignore` - never commit your credentials!

### 4. Open the Workspace

```bash
open AudioSafety.xcworkspace
```

⚠️ **Important**: Always open the `.xcworkspace` file, not the `.xcodeproj` file, when using CocoaPods.

### 5. Run the Project

1. Select your target device or simulator
2. Press `Cmd + R` to build and run

## Usage

1. **Join Channel**: App automatically joins the channel specified in `KeyStore.channelName`
2. **View Users**: Up to 8 users displayed in seat views
   - Blue seats = Local user (you)
   - Green seats = Remote users
3. **Report User**: Tap any seat to generate audio evidence
4. **Audio Files**: WAV files saved to app's temporary directory

## Project Structure

```
AudioSafety/
├── AudioSafety.swift          # Main view controller with 8-seat UI
├── AudioSafetyManager.swift   # Audio buffer manager
├── AppDelegate.swift          # App lifecycle
├── SceneDelegate.swift        # Scene management
├── Info.plist                 # App configuration
├── Podfile                    # CocoaPods dependencies
├── KeyStore.swift.example     # Template for credentials (commit this)
├── KeyStore.swift             # Your actual credentials (DO NOT COMMIT)
├── .gitignore                 # Protects credentials
└── README.md                  # This file
```

## How It Works

### Audio Buffer Management

1. **Recording State**: 
   - `startRecording()` when joining channel
   - `stopRecording()` when leaving channel

2. **User Registration**:
   - Local user automatically registered on join
   - Remote users registered when they join
   - Users unregistered when they leave

3. **Audio Capture**:
   - Local audio via `onRecordAudioFrame`
   - Remote audio via `onPlaybackAudioFrame(beforeMixing:)`
   - 48kHz, Mono, 16-bit PCM format

4. **Buffer Storage**:
   - Circular buffer (300 seconds = 5 minutes)
   - Rolling overwrites oldest data when full
   - Separate buffer per user

5. **Report Generation**:
   - Tap any seat to report that user
   - Creates WAV file with audio evidence
   - Non-destructive read (can report multiple times)

## Audio Format

- **Sample Rate**: 48,000 Hz
- **Channels**: 1 (Mono)
- **Bit Depth**: 16-bit
- **Format**: PCM, Little Endian
- **Output**: WAV files

## Permissions

The app requires the following permissions (configured in Info.plist):

- **Microphone**: For capturing local audio
- **Camera** (optional): If you add video features later

## Testing

### Simulator Testing
- Join channel on simulator
- Audio recording will work but you won't hear remote users
- Useful for UI testing

### Device Testing
- Requires physical iOS device
- Join same channel from multiple devices to test remote user features
- Can test with Android app for cross-platform verification

### Two-Device Testing
1. Device A: Join channel "AudioSafetyDemo"
2. Device B: Join same channel
3. Tap on remote user seat to generate report
4. Check console logs for WAV file paths

## Troubleshooting

### CocoaPods Issues
```bash
# Update CocoaPods
sudo gem install cocoapods
pod repo update
pod install
```

### Build Errors
- Clean build folder: `Cmd + Shift + K`
- Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`
- Re-install pods: `pod deintegrate && pod install`

### Runtime Issues
- Check microphone permissions in Settings
- Verify App ID is correct
- Check console logs for detailed errors

## Production Considerations

### Before Deploying to Production:

1. **Replace App ID**: Use your production Agora App ID
2. **Add Token Authentication**: Implement token generation for security
3. **Upload Audio Files**: Send WAV files to your moderation service
4. **Error Handling**: Add robust error handling and retry logic
5. **Analytics**: Track report events for monitoring
6. **User Privacy**: Ensure compliance with privacy regulations
7. **Storage Management**: Clean up old WAV files periodically

### Example Upload Implementation:

```swift
private func reportUser(uid: UInt) {
    // ... existing code ...
    
    manager.recordBuffer(uid: uid) { fileUrl in
        if let url = fileUrl {
            // Upload to your moderation service
            self.uploadToModerationService(fileUrl: url, reportedUid: uid)
        }
    }
}

private func uploadToModerationService(fileUrl: URL, reportedUid: UInt) {
    // Implement your upload logic here
    // Example: POST to https://your-api.com/moderation/upload
}
```

## Architecture

This implementation follows the Android reference architecture:

- **User Registration**: Only monitored users consume memory
- **Recording State**: Explicit start/stop control
- **Thread Safety**: All buffer operations on dedicated queue
- **Format Validation**: Ensures correct audio format
- **Debounce Protection**: Prevents spam reporting

## License

This is a demo implementation. Check with Agora and your organization for licensing requirements.

## Support

- [Agora Documentation](https://docs.agora.io/)
- [Agora GitHub Examples](https://github.com/AgoraIO/API-Examples)
- [Android Reference Implementation](https://github.com/AgoraIO/API-Examples/tree/dev/CSD-75694/Android/APIExample-Audio/app/src/main/java/io/agora/api/example/examples/advanced/audiosafety)
