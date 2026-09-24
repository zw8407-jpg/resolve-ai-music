# Contributing

Thank you for improving Resolve AI Music.

## Development setup

Requirements:

- macOS 13 or later
- Swift 5.9 or later
- Python 3
- FFmpeg and FFprobe for audio processing
- DaVinci Resolve Studio 21.1 for optional live integration testing

Build and test:

```bash
bash scripts/test.sh
bash scripts/build-app.sh
open "dist/Resolve AI Music.app"
```

The default test suite uses simulated cloud responses and local Resolve models.
It must not submit paid TokenHub requests or modify a user's production
timeline. Live Resolve tests must use a disposable QA project and are skipped by
default.

## Pull requests

1. Open an issue for substantial behavioral or API changes.
2. Keep pull requests focused and describe user-visible effects.
3. Add or update tests for logic changes.
4. Run `bash scripts/test.sh` before submitting.
5. Do not include generated audio, API keys, private footage, build output, or
   third-party binaries.
6. Preserve timeline ownership checks, pre-write backups, collision detection,
   and failure recovery.

## Contribution certification

This project uses the [Developer Certificate of Origin 1.1](https://developercertificate.org/).
Add a `Signed-off-by` line to every commit with `git commit -s`. By signing off,
you certify that you have the right to submit the contribution and that it may
be distributed under Apache-2.0. Do not submit code, designs, prompts, audio,
or other material that you do not have permission to contribute.
