# EpoCanvas Mail (Android)

<div align="center">
  <h3>✨ Native Android Client for EpoCanvas Mail ✨</h3>
  <p>Built with Flutter & Material Design 3</p>
</div>

---

## 📱 Features

- **🎨 Modern Material 3 UI**: Full support for Light, Dark, and System theme — synchronized with the server-bound profile (`themeMode`) like the web app.
- **⚡ Full Contract Alignment with epomail Web (mail-worker)**: Cursor-paginated `/email/list` with the real `type`/`folder` contract, `{code,data,message}` envelope, `receiveEmail` send payload, comma-joined `emailIds` mutations — verified by mock contract tests AND a live E2E suite.
- **🔐 Multi-Factor Authentication (2FA)**: Native TOTP 6-digit authenticator verification with auto-focus and auto-submit.
- **📂 Full Folder Support**: Inbox, Starred, Sent, Drafts (client-local, web parity), Snoozed, All Mail, Spam, and Trash.
- **🏷️ Labels**: Apply / filter by custom labels (`PUT /email/labels`), label rail in the drawer with unread counters from `sidebarStats.labelStats`.
- **⏰ Snooze & Restore**: Snooze presets/custom time (`PUT /email/snooze`), restore from Trash, report spam / not spam with personal blacklist sync.
- **🤖 AI Translation**: Gmail-style translate bar in the reader (`POST /email/translate`, 8 target languages), graceful degradation when the AI engine is off.
- **💌 Advanced Compose & Reply**: Rich HTML rendering, quoted reply headers, file attachments (inline base64 payload), local draft persistence, draft discard guards.
- **official Welcome Mail**: Official verified badge for `admin@epocanvas.com` welcome emails (`isOfficial`), auto-starred, with AI-extracted verification codes.
- **🔍 Instant Search**: Server-side keyword search with `searchSuggestions` support.
- **👥 Multi-Account Support**: Seamlessly switch between multiple email aliases from the navigation drawer; add/remove aliases per web permissions.
- **📊 Storage Meter**: Live storage usage card from `GET /my/storage` (quota / visitor-mode aware).
- **🧾 Registration**: In-app account creation with domain picker and registration-key support from `websiteConfig`.
- **🌐 Self-Hosted Friendly**: Dynamic server URL configuration; optional `EPO_HTTP_PROXY` env override for restricted networks.

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
