# QR Jukebox

A generic offline QR-based audio player.

## How it works

The app maps a QR Code URL to a local audio file.

**Expected QR format:**
`https://<host>/<language>/<gameId>/<trackId>`

Example:
`https://example.com/de/aaaa0015/00015`

## Folder Structure

The app expects your media to be organized as follows:

```
<Media Root>/
└── <host>/
    └── <language>/
        └── <gameId>_<Optional Game Name>/
            ├── <trackId>_<Optional Track Name>.mp3
            └── <trackId>_<Another Track>.m4a
```

- `host`: The domain from the QR code (e.g., `www.example.com`).
- `language`: The first path segment (e.g., `de`).
- `gameId`: The second path segment. The folder name must *start* with this ID.
- `trackId`: The third path segment. The file name must *start* with this ID.
