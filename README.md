# MotoRev 🏍️

**A social motorcycle safety app built in honor of Bryce Raiford**

MotoRev is a revolutionary iOS app that combines social networking with advanced safety features for motorcycle riders. Built with SwiftUI and designed to be the must-have app for every motorcyclist, MotoRev creates a vibrant community while keeping riders safe through cutting-edge crash detection and emergency response features.

## 🎯 Vision

MotoRev isn't just another safety app—it's a social platform that happens to include life-saving features. We believe that safety should be engaging, not restrictive. By combining social networking with safety technology, we create an app that riders actually want to use every day.

## ⭐ Key Features

### 🌟 Social Networking
- **Feed & Stories**: Share your rides, photos, and experiences with the motorcycle community
- **Ride Sharing**: Connect with nearby riders and join group rides
- **Leaderboards**: Compete with friends on miles ridden, safety scores, and achievements
- **Challenges**: Participate in distance, safety, and exploration challenges
- **Community Groups**: Join local riding groups and discover new riding partners

### 🛡️ Safety Features
- **Crash Detection**: Advanced algorithms using iPhone's gyroscope and accelerometer
- **Emergency Response**: Automatic emergency contact notification and 911 calling
- **Safety Scoring**: Real-time safety assessment based on riding behavior
- **Emergency Contacts**: Quick access to emergency contacts and medical information
- **Live Tracking**: Real-time location sharing with trusted contacts during rides

### 🍎 Apple Watch Integration
- **Companion App**: Full Apple Watch support for on-the-go safety monitoring
- **Emergency SOS**: Quick access to emergency features from your wrist
- **Ride Metrics**: Real-time speed, distance, and safety metrics
- **Notifications**: Safety alerts and social updates delivered to your watch

### 🗺️ Navigation & GPS
- **Real-time GPS**: Accurate location tracking and navigation
- **Route Planning**: Discover scenic routes and popular riding destinations
- **Nearby Riders**: Find and connect with riders in your area
- **Ride History**: Detailed logs of all your rides with maps and statistics

## 🚀 Getting Started

### Prerequisites
- iOS 17.0 or later
- iPhone with GPS, accelerometer, and gyroscope
- Apple Watch (optional but recommended)
- Xcode 14.0 or later for development

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/MotoRev.git
   cd MotoRev
   ```

2. **Open in Xcode**
   ```bash
   open MotoRev.xcodeproj
   ```

3. **Configure signing**
   - Select your development team in the project settings
   - Update the bundle identifier if needed

4. **Run the app**
   - Select your target device or simulator
   - Press ⌘+R to build and run

### Required Permissions

MotoRev requires several permissions to function properly:
- **Location**: For ride tracking and crash detection
- **Motion**: For crash detection using device sensors
- **Contacts**: For emergency contact management
- **Camera/Photos**: For sharing ride photos
- **Notifications**: For safety alerts and social updates
- **Bluetooth**: For Apple Watch connectivity

## 🏗️ Architecture

### Project Structure
```
MotoRev/
├── MotoRev/
│   ├── MotoRevApp.swift          # Main app entry point
│   ├── ContentView.swift         # Main tab interface
│   ├── Models/
│   │   └── DataModels.swift      # Core data models
│   ├── Managers/
│   │   ├── SafetyManager.swift   # Crash detection & safety
│   │   ├── LocationManager.swift # GPS & location services
│   │   ├── SocialManager.swift   # Social networking features
│   │   └── WatchManager.swift    # Apple Watch integration
│   ├── Views/
│   │   ├── SocialFeedView.swift  # Main social feed
│   │   ├── MapView.swift         # Navigation & GPS
│   │   ├── LeaderboardView.swift # Rankings & challenges
│   │   ├── ProfileView.swift     # User profile & settings
│   │   └── SafetyStatusOverlay.swift # Safety status indicator
│   └── Info.plist               # App configuration
└── MotoRev.xcodeproj/           # Xcode project file
```

### Key Technologies
- **SwiftUI**: Modern declarative UI framework
- **CoreLocation**: GPS and location services
- **CoreMotion**: Motion sensors for crash detection
- **MapKit**: Maps and navigation
- **WatchConnectivity**: Apple Watch integration
- **UserNotifications**: Push notifications and alerts
- **Combine**: Reactive programming for data flow

## 🔧 Configuration

### Safety Settings
The app includes configurable safety thresholds:
- **Crash Detection Threshold**: 4.0 G-force acceleration
- **Rotation Threshold**: 6.0 rad/s for sudden rotation
- **Emergency Countdown**: 30 seconds before auto-calling 911
- **Location Accuracy**: High precision for safety features

### Customization
- Adjust safety sensitivity in the settings
- Configure emergency contacts and medical information
- Set privacy preferences for social features
- Customize notification preferences

## 🤝 Contributing

We welcome contributions to MotoRev! Here's how you can help:

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. **Commit your changes**
   ```bash
   git commit -m 'Add amazing feature'
   ```
4. **Push to your branch**
   ```bash
   git push origin feature/amazing-feature
   ```
5. **Open a Pull Request**

### Development Guidelines
- Follow SwiftUI best practices
- Write comprehensive tests for safety features
- Document new features thoroughly
- Ensure accessibility compliance
- Test on real devices for motion detection

## 📱 Screenshots

_Coming soon - screenshots of the main app interface_

## 🔒 Privacy & Security

MotoRev takes privacy seriously:
- **Local Data**: Critical safety data is stored locally
- **Encrypted Communication**: All network communication is encrypted
- **Optional Sharing**: Users control what data is shared
- **No Tracking**: We don't track users for advertising purposes
- **Emergency Only**: Location data is only shared during emergencies

## 🆘 Emergency Features

### Crash Detection
- Uses iPhone's advanced motion sensors
- Machine learning algorithms to reduce false positives
- Immediate alert with 30-second countdown
- Automatic emergency contact notification

### Emergency Response
- One-touch emergency calling
- GPS location sharing with emergency contacts
- Medical information sharing with first responders
- Apple Watch emergency SOS integration

## 🎖️ In Memory of Bryce Raiford

This app is dedicated to Bryce Raiford, who was passionate about motorcycles and would have loved to see technology making riding safer for everyone. His memory drives our commitment to creating an app that not only saves lives but brings the motorcycle community together.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- The motorcycle community for inspiration and feedback
- Apple for providing excellent development tools and frameworks
- Beta testers who help make MotoRev safer and better
- Emergency responders who keep us safe on the roads

## 📞 Support

- **Issues**: Report bugs and request features on GitHub
- **Email**: support@motorev.app (coming soon)
- **Community**: Join our Discord server for discussions

## 🚧 Roadmap

### Version 1.1 (Coming Soon)
- [ ] Android version
- [ ] Group video calling
- [ ] Weather integration
- [ ] Bike maintenance tracking
- [ ] Route recommendations based on bike type

### Version 1.2 (Future)
- [ ] AI-powered safety coaching
- [ ] Integration with popular motorcycle accessories
- [ ] Advanced analytics and insights
- [ ] Marketplace for motorcycle gear

---

**Stay safe, ride smart, and remember Bryce. 🏍️❤️**

*MotoRev - Because every ride matters.* 