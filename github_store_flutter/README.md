# GitHub Store - Flutter Desktop

A feature-rich GitHub Store desktop application rewritten from Kotlin Multiplatform to Flutter Desktop.

## Features

- **Discover** — Trending, hot releases, popular repos, category browsing
- **Download & Install** — One-click download and install GitHub releases
- **Star & Favorite** — Star repos, manage favorites locally
- **Background Updates** — Auto-check for installed app updates
- **GitHub Login** — OAuth device flow authentication
- **Multi-language** — English, Chinese, and more
- **Themes** — 6 color schemes, light/dark/AMOLED modes
- **Cross-platform** — Windows, macOS, Linux

## Why Flutter?

| | Kotlin (Original) | Flutter (Rewrite) |
|--|--|--|
| Package Size | 209 MB | ~15-25 MB |
| Desktop Runtime | JBR 21 (150MB) | Native (~5MB) |
| Rendering | Skiko (35MB) | Skia (bundled) |

## Getting Started

```bash
# Clone
git clone https://github.com/xiaijiangxue/GitHub-Store-Flutter.git

# Install dependencies
flutter pub get

# Run
flutter run -d windows  # or macos, linux
```

## Build

```bash
# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux (requires gtk3-dev)
flutter build linux --release
```

## Tech Stack

- **Framework**: Flutter 3.29 (Desktop)
- **State Management**: Riverpod 2.x
- **Networking**: Dio 5.x
- **Database**: SQLite (direct)
- **Routing**: GoRouter 14.x
- **Localization**: intl + ARB

## Architecture

```
lib/
├── core/           # Infrastructure (network, database, theme, cache)
├── features/       # Feature modules (home, search, details, etc.)
│   ├── */data/         # Repository layer
│   └── */presentation/ # UI + providers
├── shared/         # Shared widgets
├── l10n/           # Localization
├── app.dart        # Root widget
└── main.dart       # Entry point
```

## License

MIT
