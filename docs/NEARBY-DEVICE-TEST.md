# Nearby test builds — 11 November 2026

These are unpublished test builds: Mac 0.6.0 (15), iPad 1.1 (21).

The revised iPad build was installed and launched successfully on 11 November; device inventory confirmed 1.1 (21).

## Owner-reported physical results — 11 November

- The MacBook → iPad screenshot → annotation → Done → MacBook paste workflow succeeded after Wi-Fi was restored on the devices.
- With the iPad moved to the phone hotspot while the MacBook stayed on its normal Wi-Fi, new screenshots stopped appearing. This initial build 19 different-network test **failed**; subsequent build results follow below.
- Fresh pairing with the explicit Nearby QR also failed on different networks; the iPad reported it could not connect. The successful same-network test does not validate peer-to-peer operation.
- Build 20 adds explicit peer-to-peer Bonjour browsing before connecting, stops the browser before transfer, and distinguishes missing peers from permission and connection failures. The owner then confirmed the full capture → iPad annotation → Done → MacBook paste workflow worked on different networks, but the screenshot took **over 45 seconds** to appear. This is an owner-reported physical success with unacceptable startup latency, not a release-ready performance result. The actual radio interface was not instrumented, and an isolated guest network has not been tested.
- All 48 native tests and the standalone encrypted discovery/transport checks passed. A new missing-peer diagnostic regression failed before the change and passed afterward.

## Build 21 latency follow-up

A simulator regression reproduced a stale background poll blocking library refresh after a new pairing succeeded. Build 21 cancels the obsolete poll when configuring the new connection, propagates lifecycle cancellation, and prevents cancelled/stale operations from replacing current connection state or showing irrelevant image errors. The regression uses isolated HTTP and credential storage; it failed before the fix and passed afterward. All 49 native tests passed. Repeated discovered connections with simultaneous library polling and 2 MiB synthetic saves also passed on the Studio, which does not measure physical wireless latency.

The signed build was installed in place. The owner subsequently reported that the different-network test worked and the screenshot arrived much faster. This confirms a qualitative physical improvement for build 21; no exact timings or separate first/second screenshot measurements were provided. The full round trip had already been confirmed on build 20. An actual client-isolated guest network, repeated batches, and sleep/wake/network-switch recovery remain release checks.

## Install

1. AirDrop `build/nearby-testing/Ludwigs-Annotated-Screenshots-0.6.0-15-Mac-test.zip` from the Mac Studio to the MacBook Pro.
2. Quit Ludwig on the MacBook. Keep a backup copy of the old application, unzip the test app, and copy it into Applications. Open it. The test app is signed and notarized and includes its runtime; no Python or Xcode installation is needed on the MacBook.
3. Connect the iPad to the Mac Studio by USB, unlock it, and accept Trust if prompted. Save any open annotation with Done. Keep the existing Ludwig app installed so the test build can update it in place.
4. Enable Settings → Privacy & Security → Developer Mode on the iPad. Follow its restart and confirmation prompts, then unlock it. Install the signed 1.1 (21) build from the Studio. USB is only needed for installation; afterward the iPad can connect wirelessly to the MacBook.

## First connection

1. Keep MacBook and iPad nearby with Wi-Fi and Bluetooth on. Start with both on the normal Wi-Fi and open Ludwig on both devices. Allow Local Network access if prompted.
2. Open Connect iPad on the Mac and select **Nearby · iPad 1.1+**.
3. Scan that fresh QR using the scanner inside Ludwig on the iPad. Do not share the QR: it grants access to that Mac's library.
4. Capture a harmless test screenshot on the MacBook. Confirm it appears on the iPad, add a Pencil mark, tap Done, then paste into a document on the MacBook. Confirm the marked image is pasted.

## Router-independent test

1. Keep both radios enabled and the apps open. Connect the iPad to a phone hotspot while the MacBook remains on its normal Wi-Fi (or vice versa). Do not turn Wi-Fi off.
2. Repeat capture → annotation → Done → Mac paste. Record success or the exact error and the step that failed.
3. Repeat on the actual guest/shared network that blocks communication between clients when available. Different-network testing does not reproduce every guest-network condition.
4. Check a small batch, a Wi-Fi change, sleep/wake, relaunch, and switching Macs by scanning each Mac's fresh Nearby QR. Existing drafts should remain available when returning to their original Mac.

The owner has reported successful different-network operation and faster arrival on build 21. Actual isolated guest-network validation remains pending. Nearby is designed to avoid relying on the shared router; success on every hardware, VPN, managed-device, or radio configuration is not established. The Safari / iPad 1.0 mode retains its original private-network requirements.
