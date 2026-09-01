# EpoCanvas Mail (Android)

<div align="center">
  <h3>✨ Native Android Client for EpoCanvas Mail ✨</h3>
  <p>Built with Flutter & Material Design 3</p>
</div>

---

## 📱 Features

- **🎨 Modern Material 3 UI**: Full support for Light, Dark, and System theme synchronization.
- **⚡ High-Performance Email Engine**: Paginated loading, background synchronization, pull-to-refresh, and local caching.
- **🔐 Multi-Factor Authentication (2FA)**: Native TOTP 6-digit authenticator verification with auto-focus and auto-submit.
- **📂 Full Folder Support**: Inbox, Sent, Drafts, Starred, Spam, Trash, and All Mail categories.
- **💌 Advanced Compose & Reply**: Rich HTML rendering, quoted reply headers, CC/BCC support, and draft discard guards.
- **🔍 Instant Search**: Real-time keyword filtering and search suggestions.
- **👥 Multi-Account Support**: Seamlessly switch between multiple email aliases and accounts from the navigation drawer.
- **🌐 Self-Hosted Friendly**: Dynamic server URL configuration with health check detection.

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/) (>= 3.2.0)
- [Android SDK](https://developer.android.com/) (API 23+)
- Java JDK 17

### Installation & Build

1. Clone the repository:
   ```bash
   git clone git@github.com:shijianus/epomail-android.git
   cd epomail-android
   ```

2. Fetch Flutter packages:
   ```bash
   flutter pub get
   ```

3. Build Release APK:
   ```bash
   flutter build apk --release
   ```
   The generated APK will be available at:
   `build/app/outputs/flutter-apk/app-release.apk`

---

## 📦 Project Architecture

```
lib/
├── api/            # REST API client & endpoints (Dio wrapper)
├── models/         # Strongly-typed Dart data models
├── providers/      # State management using Provider pattern
├── screens/        # UI Views (Auth, Home, Detail, Compose, Settings)
├── theme/          # App design tokens, typography & color palettes
├── utils/          # Date & text helper utilities
└── widgets/        # Reusable UI components
```

---

## 📄 License
MIT License.
