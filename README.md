# 🎵 QR Jukebox

A lightweight, generic offline audio player that maps QR codes to your local music library. Perfect for DIY board games, scavenger hunts, or interactive exhibits.

## 🚀 How it works

The app scans a QR code containing a URL and maps it to a specific local audio file by mirroring the URL's path structure in your local filesystem.

**Generic Path Mapping:**
- The **Domain** of the URL is the root folder.
- All **Path Segments** before the last one are treated as subdirectories.
- The **Last Segment** is the Track ID (filename prefix).

Example: `https://example.com/en/collection01/00042`
Maps to: `<Media Root>/example.com/en/collection01/00042_*.mp3`

> [!TIP]
> **Coincidence?** This logic makes the app compatible with many popular modern music trivia games. If you have a local collection of the songs from your favorite game (e.g., *Hitster*), you can use this app as a fast, offline alternative to the official online player. It even supports the original edition URLs like `hitstergame.com/de/00308`.

## 📂 Folder Structure

Organize your media root folder to match the URLs you intend to scan. Folders and files can have optional descriptive suffixes after an underscore.

```text
<Media Root>/
└── example.com/
    └── en/
        └── collection01_Superhits/
            ├── 00042_Song Title.mp3
            └── 00043_Another Track.m4a
```

Supported formats: `.mp3`, `.m4a`, `.wav`, `.flac`.

## ✨ Features

- **Offline First**: No internet connection required once your media is on the device.
- **Privacy Focused**: No tracking, no ads, no cloud sync.
- **Metadata & Art**: Displays Title, Artist, Album, and Fullscreen Cover Art from ID3 tags.
- **Customizable Playback**: Set a global start offset (e.g., 30s) to skip intros.
- **Game Timer**: Optional stopwatch to track "thinking time" per card.
- **Easy Navigation**: Quick 10s skip buttons and marquee for long titles.
- **Orientation Lock**: Fixed portrait mode for a consistent gaming experience.
- **Easy Setup**: Built-in directory picker for your media library.

## 🛠️ Built With

This project is built with [Flutter](https://flutter.dev) and powered by these amazing open-source libraries:

- **[mobile_scanner](https://pub.dev/packages/mobile_scanner)** - High-performance QR code scanning.
- **[audioplayers](https://pub.dev/packages/audioplayers)** - Reliable audio playback.
- **[audiotags](https://pub.dev/packages/audiotags)** - Extracting metadata and album art.
- **[file_picker](https://pub.dev/packages/file_picker)** - Native directory selection.
- **[marquee](https://pub.dev/packages/marquee)** - Smooth scrolling for long titles.
- **[url_launcher](https://pub.dev/packages/url_launcher)** - Opening external links.
- **[path](https://pub.dev/packages/path)** - Cross-platform path manipulation.
- **[permission_handler](https://pub.dev/packages/permission_handler)** - Managing Android storage permissions.
- **[wakelock_plus](https://pub.dev/packages/wakelock_plus)** - Prevents the device from sleeping while playing.

## ⚖️ License

This project is licensed under the **MIT License**.

---
*Disclaimer: This app is a generic tool and not affiliated with, endorsed by, or associated with any specific board game manufacturer.*
