# AirCard-iOS 26.4 experimental build

This branch does not claim that changing the deployment target makes the
AirTraffic exploit compatible with iOS 26.4. The upstream deployment target is
already iOS 18.0.

It adds an on-device compatibility probe that exercises the same connection and
AirTraffic traversal primitive used by Wallet flashing, but targets a randomized
canary in `/var/mobile/Library/Caches` instead of Passbook. A pass requires all
of the following:

- loopback plus pairing reaches the device service tunnel;
- AFC and `com.apple.atc` are available;
- the traversal writes a new randomized file;
- the exact bytes can be exported and verified;
- temporary AFC objects are removed.

Only after the probe passes should Wallet artwork flashing be tested. A probe
failure is expected to leave Wallet untouched and provides a stage-specific log
for adapting the iOS 26.4 protocol or paths.

## Build an unsigned IPA on macOS

Requirements: macOS 14+, Xcode 16+, and XcodeGen. The checked-in
`AirliftFFI.xcframework` is used, so rebuilding Rust is not required for this
Swift-only compatibility build.

```sh
brew install xcodegen
cd AirCard-iOS-26.4
xcodegen generate
./build-ipa.sh
```

The result is `build/AirCard-iOS.ipa`. Sign it with SideStore, AltStore,
TrollStore, LiveContainer, Xcode, or another signing method you control.

## Device test order

1. Install and open Apple Books once.
2. Start LocalDevVPN or another working loopback tunnel.
3. Pair in Settings, or import a pairing record.
4. Run **iOS 26.4 Compatibility > Run iOS 26.4 Probe**.
5. Export the complete probe log if it fails. Do not post pairing records or
   card identifiers.
6. Only after a fully green probe, scan one Wallet card and test one disposable
   artwork change before using batch flash.

This is an experimental research build. It changes local artwork caches only;
it does not alter payment credentials or bank-side card data.

## Start the build from Windows

Windows cannot run Apple's iOS SDK or `xcodebuild` locally. The included
PowerShell script uploads the source to a GitHub repository, starts the included
macOS Actions workflow, downloads the unsigned IPA, and verifies its SHA-256
checksum. The final file is still placed in `build/AirCard-iOS.ipa` on Windows.

Install and sign in to GitHub CLI once:

```powershell
winget install --id GitHub.cli
gh auth login
```

Then run this inside the source directory. The script reads your authenticated
GitHub username and creates `AirCard-iOS-26.4-private` automatically:

```powershell
powershell -ExecutionPolicy Bypass -File .\build-from-windows.ps1
```

Do not add a trailing backtick to this one-line command. To choose another
repository explicitly, use a real account name such as
`-Repository "octocat/AirCard-iOS-26.4-private"`.

For the existing `rnadow/aircard` repository, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\build-from-windows.ps1 -Repository "rnadow/aircard"
```

The repository is private by default. The downloaded IPA is unsigned and must
be signed by the sideloading method you control before installation.
