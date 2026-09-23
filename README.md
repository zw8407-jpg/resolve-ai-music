# Resolve AI Music

<p align="center">
  <img src="Assets/AppIconSource.png" width="128" height="128" alt="Resolve AI Music icon">
</p>

**Generate music from text or script context and place it directly on a
DaVinci Resolve timeline.**

[简体中文](README.zh-CN.md)

Resolve AI Music is a native macOS menu-bar application for editors and content
creators. It reads the current Resolve In-Out range or playhead, requests an
instrumental cue through TokenHub MiniMax Music, normalizes the result to a
48 kHz stereo WAV, and inserts it into managed main and alternate tracks.

> Public preview. Use a duplicate project or disposable timeline until the
> workflow has been validated for your Resolve setup.

## Features

- Uses the current In-Out range, or a configurable duration from the playhead.
- Accepts a music brief, script text, or on-device voice input.
- Includes ten music-style presets and local prompt variations.
- Manages a main version and muted alternate version on an available track pair.
- Preserves unrelated clips, checks collisions, and creates a timeline backup
  before writes.
- Supports Simplified Chinese, Traditional Chinese, English, Japanese, Korean,
  and Spanish. Simplified Chinese is the default.
- Stores the TokenHub key in macOS Keychain.
- Provides recovery entries for downloaded audio and previous versions.

## Requirements

- macOS 13 or later
- Apple Silicon Mac (the current release is developed and tested on arm64)
- DaVinci Resolve Studio 21.1 at its default application path
- Resolve external scripting enabled and ResolveMCP installed with Resolve
- FFmpeg and FFprobe available in `/opt/homebrew/bin` or `/usr/local/bin`
- A user-provided TokenHub API key with the required language and music models
  enabled

Install FFmpeg with Homebrew:

```bash
brew install ffmpeg
```

## Build from source

```bash
git clone https://github.com/zw8407-jpg/resolve-ai-music.git
cd resolve-ai-music
bash scripts/test.sh
bash scripts/build-app.sh
open "dist/Resolve AI Music.app"
```

The local build is ad-hoc signed and intended for development. Public binary
releases must be signed with Developer ID, hardened, and notarized. See
[`docs/releasing.md`](docs/releasing.md).

## Setup

1. Open a Resolve project and timeline.
2. Launch Resolve AI Music and open **Settings**.
3. Paste your TokenHub `sk-…` key and save it to Keychain.
4. Grant Accessibility permission if you want the middle-button double-click
   shortcut. The menu-bar icon remains available without that permission.
5. Set an In-Out range or place the playhead, choose a duration and style, and
   edit the music brief.
6. Select the main or alternate target and generate one track.

The app initially prefers A3/A4. If either track contains foreign or locked
content, it proposes another consecutive empty pair instead of overwriting it.
Track colors are not changed through automation; set the main track to purple
and the alternate track to blue manually if desired.

## Data, cost, and recovery

- Music and text-model calls may incur TokenHub charges. The app submits one
  music request at a time and does not blindly retry paid requests.
- The selected script or prompt is sent only after an explicit analysis or
  generation action. See [`PRIVACY.md`](PRIVACY.md).
- Application data is stored under
  `~/Library/Application Support/ResolveAIMusic/`.
- Generated audio should not be moved while a Resolve project references it.
- Every managed timeline write uses ownership markers, collision checks, and a
  pre-write timeline duplicate for recovery.

## Development

The standard suite is safe and uses mock cloud responses:

```bash
bash scripts/test.sh
```

Live Resolve integration is skipped by default. See
[`docs/development.md`](docs/development.md) and
[`CONTRIBUTING.md`](CONTRIBUTING.md).

## Distribution and third parties

This repository does not distribute Resolve, ResolveMCP, FFmpeg, MiniMax, or
TokenHub binaries. Users install third-party software and obtain service access
under the applicable provider terms.

DaVinci Resolve is a trademark of Blackmagic Design Pty Ltd. MiniMax, TokenHub,
Tencent Cloud, Apple, and macOS marks belong to their respective owners. This
independent project is not endorsed by or affiliated with those companies.

## License

Source code and documentation are licensed under the
[Apache License 2.0](LICENSE). Product naming and visual identity are subject to
[`TRADEMARKS.md`](TRADEMARKS.md).
