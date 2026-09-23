# Privacy

Resolve AI Music is a local macOS application. It does not include analytics,
advertising, account registration, or developer-operated telemetry.

## Data stored locally

- The TokenHub API key is stored in macOS Keychain.
- Preferences, operation history, version metadata, and cached audio are stored
  under `~/Library/Application Support/ResolveAIMusic/`.
- Generated audio and Resolve timeline backups remain on the user's computer
  unless the user moves or shares them.

## Data sent to third parties

- Clicking **Generate** sends the music prompt and generation parameters to the
  configured TokenHub music endpoint.
- Clicking **Analyze script** or **Refine brief** sends the current text to the
  configured TokenHub language model endpoint.
- The API key is sent only in the HTTPS authorization header for those explicit
  requests. It is not written to logs or command-line arguments.
- Voice input uses Apple's on-device speech recognition requirement in the
  current implementation. The app requests microphone and speech-recognition
  permission only when voice input is used.

TokenHub, MiniMax, Apple, and any network provider process data under their own
terms and privacy policies. Users are responsible for reviewing those terms
before sending confidential scripts or other protected material.

## Deleting local data

Quit the app, remove `~/Library/Application Support/ResolveAIMusic/`, and delete
the `io.github.zw8407-jpg.ResolveAIMusic.tokenhub` generic password item from
Keychain Access. Older development builds may also have created a
`com.local.ResolveAIMusic.tokenhub` item. Do not remove generated audio that is
still referenced by a Resolve project unless you have first consolidated or
relinked that project.
