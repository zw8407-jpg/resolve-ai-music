# Release process

Public source and binary releases are separate. The source repository does not
track `dist/` or compiled applications.

## Prerequisites

- The stable bundle identifier `io.github.zw8407-jpg.ResolveAIMusic`
- Apple Developer Program access
- A valid `Developer ID Application` certificate
- Xcode command-line tools with `notarytool` and `stapler`
- A Keychain profile created without placing credentials in scripts:

```bash
xcrun notarytool store-credentials "resolve-ai-music-notary" \
  --apple-id "YOUR_APPLE_ID" \
  --team-id "YOUR_TEAM_ID" \
  --password "APP_SPECIFIC_PASSWORD"
```

The command above is interactive security setup. Do not paste its values into
issues, logs, source files, GitHub Actions, or shell history shared with others.

## Build, sign, notarize, and package

```bash
export SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="resolve-ai-music-notary"
bash scripts/package-release.sh
```

The script runs tests, builds the app, applies hardened-runtime signing,
submits a temporary ZIP for notarization, staples and validates the ticket, and
creates a final ZIP plus `SHA256SUMS.txt` under `dist/release/`.

## Release checklist

1. Confirm the version and build number in `packaging/Info.plist`.
2. Run `bash scripts/check-public-tree.sh` and `bash scripts/test.sh`.
3. Run `bash scripts/package-release.sh`.
4. Test the ZIP on a clean macOS account with no development checkout.
5. Verify first-launch Gatekeeper, Keychain, Accessibility, microphone, speech,
   Resolve connection, generation failure handling, and a disposable timeline.
6. Create a signed Git tag matching the version.
7. Draft the GitHub Release, attach the final ZIP and checksum, and publish it
   only after installation testing passes.

Do not publish the ad-hoc signed application produced by `build-app.sh` as an
end-user release.
