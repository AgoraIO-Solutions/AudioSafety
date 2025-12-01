# AudioSafety iOS - Quick Start Guide

## 🚀 Ready to Run in 3 Steps!

Your project is **fully configured** and ready to run! Just follow these 3 simple steps:

### Step 1: Get Your Agora App ID (Free)

1. Go to [Agora Console](https://console.agora.io/)
2. Sign up/Login (free account)
3. Create a new project
4. Copy your **App ID**

### Step 2: Configure App ID

Open `AudioSafety.swift` and replace this line:

```swift
private let AppID = "YOUR_APP_ID"  // ← Replace with your App ID
```

With your actual App ID:

```swift
private let AppID = "your_actual_app_id_here"
```

### Step 3: Run the App

```bash
# Open the workspace (NOT the .xcodeproj!)
open AudioSafety.xcworkspace
```

Then in Xcode:
- Select a device or simulator
- Press `Cmd + R` (or click the Play button)

## ✅ What's Already Set Up

- ✅ Xcode project configured
- ✅ Agora SDK installed (v4.4.0)
- ✅ All source files in place
- ✅ Info.plist with permissions
- ✅ CocoaPods dependencies resolved

## 📱 Testing

### On Simulator:
- Works great for UI testing
- Audio recording works but you won't hear remote users
- Good for development

### On Real Device (Recommended):
1. Connect your iOS device
2. Select it as target in Xcode
3. You may need to:
   - Enable Developer Mode on device
   - Trust your computer
   - Set up code signing (automatic in most cases)

## 🎯 How to Use the App

Once running:

1. **Auto-Join**: App automatically joins "AudioSafetyDemo" channel
2. **See Users**: Up to 8 users shown in colored seats
   - Blue = You (local user)
   - Green = Other users
3. **Report User**: Tap any seat to generate audio evidence
4. **Check Console**: WAV file paths printed in Xcode console

## 🔧 Troubleshooting

### "No such module 'AgoraRtcKit'"
```bash
pod install
open AudioSafety.xcworkspace  # Make sure to use .xcworkspace!
```

### Build Errors
```bash
# Clean build
Cmd + Shift + K in Xcode

# Or command line:
xcodebuild clean -workspace AudioSafety.xcworkspace -scheme AudioSafety
```

### Microphone Permission Denied
- Go to Settings → Privacy → Microphone
- Enable for your app

### Can't Hear Remote Users
- Make sure you're testing on a real device (not simulator)
- Join same channel from two devices
- Check console logs for "User joined" messages

## 📂 Project Structure

```
AudioSafety/
├── AudioSafety.swift           ← Main UI (8 seats)
├── AudioSafetyManager.swift    ← Audio buffer manager
├── AppDelegate.swift           ← App lifecycle
├── SceneDelegate.swift         ← Scene setup
├── Info.plist                  ← Permissions
├── Podfile                     ← Dependencies
└── README.md                   ← Full documentation
```

## 🧪 Multi-Device Testing

### Test with 2 Devices:

**Device A:**
```bash
# Build and run
# App joins "AudioSafetyDemo"
# You'll see yourself in a blue seat
```

**Device B:**
```bash
# Build and run on second device
# Joins same "AudioSafetyDemo" channel
# Both devices see each other
```

**Report User:**
- Tap on the remote user's green seat
- Check console for WAV file path
- File contains 5 minutes of rolling audio

## 💡 Tips

### Change Channel Name
In `AudioSafety.swift`:
```swift
private let ChannelName = "MyTestChannel"  // Change this
```

### Change Buffer Duration
In `AudioSafety.swift`:
```swift
safetyManager = AudioSafetyManager(
    agoraKit: agoraKit, 
    bufferDurationSeconds: 600  // 10 minutes instead of 5
)
```

### Production Deployment
See `README.md` for:
- Token authentication setup
- Upload audio files to moderation service
- Privacy compliance
- Storage management

## 🎉 You're All Set!

Your project is ready to run. Just add your Agora App ID and you're good to go!

Questions? Check the full `README.md` or [Agora Documentation](https://docs.agora.io/).
