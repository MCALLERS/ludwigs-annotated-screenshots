# Mac 0.6.0 and iPad 1.1

Release authorized on 11 November 2026 after the owner tested capture → annotation → Done → Mac paste across different Wi-Fi networks, then confirmed much faster arrival with iPad build 21.

## Changes

- Mac 0.6.0 (16) adds authenticated, encrypted Nearby connections for iPad 1.1 (21), with version-specific QR choices.
- iPad discovers the paired Mac before connecting, shows Nearby or Local Wi-Fi status, and distinguishes discovery and permission failures.
- Re-pairing cancels obsolete background polls immediately instead of blocking screenshot refresh until timeout. Existing drafts and retry identifiers remain intact.
- Safari and iPad 1.0 remain supported through the explicit legacy mode on a trusted private network. The Mac retains the legacy HTTP listener for compatibility.

## Distribution

Mac release: https://github.com/MCALLERS/ludwigs-annotated-screenshots/releases/tag/v0.6.0

Mac 0.6.0 (16) was published on 11 November 2026. The app and installer are Developer ID signed, notarized, and stapled. An anonymous download of the public DMG matched its published SHA-256 checksum, passed signature, Gatekeeper, and stapling checks, and passed packaged runtime/protocol verification after mounting. SHA-256: `babf579382dd545a8dda54247cbf21db6d1092790308c3749c02af9bb292d3cc`.

iPad 1.1 (21) was submitted on 11 November 2026 at 6:15 PM EST. App Store Connect confirmed **Waiting for Review**, submission `7bdcaa4e-d1bb-4013-9286-0b2ccdc15fee`, with automatic release after approval. On 12 November 2026, the public US App Store listing confirmed **Version 1.1**, free, with its Nearby release notes. Automatic release completed. The website provides the Mac 0.6.0 download and directs current iPad users to Nearby pairing.

## Validation and limits

49 native simulator tests, 17 Python tests, and 15 Safari tests passed. Dedicated encrypted transport checks covered binary uploads, discovery filtering, cancellation, wrong-key rejection, malformed inputs, and repeated concurrent polling/uploads. The re-pairing latency regression failed before the fix and passed afterward. The final Mac app passed self-test and packaged runtime/protocol verification using synthetic data.

Physical results are owner-reported; exact timings and the selected radio interface were not instrumented. Actual isolated guest-network, extended batch/sleep-wake, and broader hardware testing remain unverified. No guarantee of every shared network or managed-device configuration is made.

## Upgrade

Quit the old Mac companion, install 0.6.0, and run only one companion. Screenshot folders and pairing identity remain in place. For iPad 1.0 choose Safari / iPad 1.0 and use a trusted private network. After updating to iPad 1.1, choose Nearby and scan its QR inside Ludwig. Keep Wi-Fi and Bluetooth on and both apps open.
