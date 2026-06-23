# 🎵 QR Jukebox

A lightweight, generic offline audio player that maps QR codes to your local music library. Perfect for DIY board games, scavenger hunts, or interactive exhibits.

## 🚀 How it works

The app scans a QR code containing a URL and maps it to a specific local audio file based on the URL path segments.

**Expected QR URL format:**
`https://<host>/<language>/<gameId>/<trackId>`

Example:
`https://example.com/en/collection01/00042`

> [!TIP]
> **Coincidence?** This URL format is (purely by chance) compatible with many popular modern music trivia games. If you happen to have a local collection of the songs from your favorite game (e.g., *Hitster*), you can use this app as a fast, offline alternative to the official online player.

## 📂 Folder Structure

Organize your media root folder as follows for the app to find your tracks:

```text
<Media Root>/
└── <host>/
    └── <language>/
        └── <gameId>_<Optional Name>/
            ├── <trackId>_<Track Name>.mp3
            ├── <trackId>_<Another Track>.m4a
            └── ...
```

- **host**: The domain from the QR code (e.g., `example.com`).
- **language**: The first path segment (e.g., `en`).
- **gameId**: The folder name must *start* with this ID (e.g., `aaaa001`).
- **trackId**: The file name must *start* with this ID (e.g., `00042`).

Supported formats: `.mp3`, `.m4a`, `.wav`, `.flac`.

## ✨ Features

- **Offline First**: No internet connection required once your media is on the device.
- **Privacy Focused**: No tracking, no ads, no cloud sync.
- **Metadata Support**: Displays Title, Artist, and Album from ID3 tags.
- **Spoiler Protection**: Long-press the music icon to "peek" at the album cover without spoiling it for others.
- **Easy Setup**: Built-in directory picker for your media library.

## 🛠️ Built With

This project is built with [Flutter](https://flutter.dev) and powered by these amazing open-source libraries:

- **[mobile_scanner](https://pub.dev/packages/mobile_scanner)** - High-performance QR code scanning.
- **[audioplayers](https://pub.dev/packages/audioplayers)** - Reliable audio playback.
- **[audiotags](https://pub.dev/packages/audiotags)** - Extracting metadata and album art.
- **[file_picker](https://pub.dev/packages/file_picker)** - Native directory selection.
- **[marquee](https://pub.dev/packages/marquee)** - Smooth scrolling for long titles.
- **[path](https://pub.dev/packages/path)** - Cross-platform path manipulation.
- **[permission_handler](https://pub.dev/packages/permission_handler)** - Managing Android storage permissions.

## ⚖️ License

This project is licensed under the **MIT License**.

---
*Disclaimer: This app is a generic tool and not affiliated with, endorsed by, or associated with any specific board game manufacturer.*
