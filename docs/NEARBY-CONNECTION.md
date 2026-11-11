# Nearby connection update — local validation, 10 November 2026

## Status

- **Website:** App Store announcement and setup guide published from commit `c3fed95` through the existing Cloudflare deployment. Live homepage, `/setup`, and `/privacy` verified in Chrome. Only website files were committed and pushed.
- **App Store:** the existing iPad app is free and publicly available at https://apps.apple.com/us/app/ludwigs-annotated-screenshots/id6827539095. Apple's US iPad web search returns it first for the full name. This does not establish ranking for generic terms or availability in other storefronts. App Store Connect asked for a fresh sign-in; the internal approval date/current territory settings were not re-read.
- **Connection update:** unpublished test builds. Mac **0.6.0 (15)**; iPad **1.1 (21)**. On 11 November, the self-contained Mac test app was Developer ID signed and notarized after explicit owner approval; the final extracted ZIP passed signature, stapler, and Gatekeeper checks. The iPad test build was installed and launched on the owner's USB-connected iPad; installed version **1.1 (21)** was verified using device app inventory. The owner confirmed the full different-network round trip on build 20, with over 45 seconds of screenshot-arrival latency. Build 21 fixes a reproduced obsolete-poll delay after re-pairing; the owner subsequently confirmed that the different-network test worked much faster. Exact timings and the radio interface were not measured. An actual isolated guest-network test and recovery/batch checks remain outstanding. Do not announce this feature as released.

## Test distribution — 11 November 2026

- Transfer ZIP: `build/nearby-testing/Ludwigs-Annotated-Screenshots-0.6.0-15-Mac-test.zip`.
- SHA-256: `b1b1d317d9a0448ad325134c97e23900a2f0263f02ddbaba94069f362e7183e7`.
- Apple notarization submission `b73d49b7-cc05-49a7-883a-645fb3126cda`: **Accepted**. Ticket stapled before creating the transfer ZIP. The app was extracted into an isolated directory and verified there.
- Mac self-test and packaged companion verification passed; bundled runtime works without Homebrew on PATH. No public download was replaced.
- Signed iPad app: `work/nearby-distribution/ipad-device/Build/Products/Debug-iphoneos/Ludwig's Annotated Screenshots.app`, bundle `com.mcallers.screenshottool.ipad`, version **1.1 (19)**. Build succeeded using the existing Apple Development identity and provisioning profile.
- After the owner enabled Developer Mode, the first installation failed because the cached provisioning profile covered a different iPad. Xcode refreshed automatic provisioning for the connected device and rebuilt successfully. Installation then succeeded without an uninstall or data-clearing operation. Device app inventory confirmed **1.1 (19)** and the launch command succeeded. Existing drafts have not been inspected or independently validated.
- Distribution logs: `work/nearby-distribution/`, including `ipad-device-refresh.log`, `ipad-install.json`, `ipad-app-after.json`, and `ipad-launch.json`. See the owner-reported results and pending build 20 retest in the device test notes. See `docs/NEARBY-DEVICE-TEST.md` for the test sequence.

The owner confirmed a fresh QR from the MacBook Pro failed on shared Wi-Fi but worked using a phone hotspot. Router client isolation is the leading explanation; it is not proven without that network. The old transport requires a reachable private Mac IP address and offers no peer-to-peer path, so rescanning cannot solve network isolation.

## Build 20 discovery revision — 11 November 2026

The iPad now shows Nearby or Local Wi-Fi beside its connection state. Polling surfaces discovery and Local Network permission errors rather than replacing them with a generic interruption message. The 45-second request bound includes discovery; cancellation and completion stop the browser. TLS-PSK authentication and draft/save identifiers remain unchanged. Mac 0.6.0 (15) remains compatible and does not need replacement for this test.

The signed build was installed in place and launched; device inventory confirmed 1.1 (20). All 48 native tests and standalone discovery/transport tests passed, including absent/unrelated peers and cancellation during browsing. Logs are `work/nearby-distribution/discovery-before.log`, `discovery-after.log`, `ipad-build-20-tests.log`, `ipad-install-20.json`, and `ipad-app-after-20.json`. The owner subsequently confirmed the full different-network round trip with over 45 seconds of arrival latency. Build 21 cancels obsolete polling after re-pairing; all 49 native tests passed, including a regression that failed before this fix. See the device test notes for timing follow-up.

Discovery lifecycle reference: https://developer.apple.com/documentation/technotes/tn3213-moving-from-multipeer-connectivity-to-network-framework.

## Implementation

The native apps use Network.framework with `includePeerToPeer = true`. A `ludwig://nearby/#pair=...` QR contains the existing random pairing secret, with no IP address. From iPad build 20, each request first browses for the paired Mac's stable Bonjour service (`_ludwig-p2p._tcp`) with peer-to-peer enabled, filters for the expected service name, stops browsing, and connects using the discovered endpoint. Build 19 attempted direct service resolution without an explicit browse. Whether this was the cause of the physical failure remains unconfirmed. Only a domain-separated hash of the secret is advertised. Name conflicts fail visibly instead of silently changing the advertised identity.

TLS 1.2 PSK authenticates both peers and encrypts the native transport with AES-128-GCM. The key is derived with HKDF-SHA256 from the pairing secret. Apple's current NWConnection TLS-PSK implementation does not support TLS 1.3. There is no accept-all certificate callback, public Internet endpoint, relay account, or plaintext fallback from a Nearby pairing.

`Shared/NearbyTransport.swift` is compiled into both targets. Requests and responses use bounded length-prefixed JSON with base64 payloads, 40 MiB bodies, a 56 MiB frame ceiling, a 45-second deadline, cancellation, and four concurrent Mac connections. Incoming bytes accumulate in one reserved buffer. The Mac bridge allows only existing library/image/save/status/session/cleanup operations and approved headers, and forwards to the authenticated API over **loopback**. Existing save UUIDs, clipboard acknowledgements, session resets and reviewed Trash cleanup keep their semantics.

Existing HTTP pairing remains supported for Safari and iPad 1.0 through the Mac's **Safari / iPad 1.0** QR selection. That legacy service still uses unencrypted private-LAN HTTP, retains the old IP-change restriction, and must be used only on trusted networks. The Mac continues to run that legacy listener for compatibility. Anyone possessing the pairing secret has library access; never share QR codes. Nearby does not make a simultaneous legacy HTTP session safe on an untrusted network.

Switching the same Mac from HTTP to Nearby preserves the draft namespace because it retains the pairing secret. Switching to another Mac still requires scanning that Mac's QR and uses a separate draft namespace. Existing Keychain records remain decodable. The iPad footer now reads the actual bundle version instead of hard-coded beta text. The generated project includes Bonjour declarations and the existing UserDefaults privacy reason (`CA92.1`) in its archived manifest.

## Validation completed

- A failing standalone regression first demonstrated that the old parser rejected address-independent pairing; it now passes nearby/legacy pairing, draft identity, persistence, and malformed-link rejection.
- **48 native simulator tests**, **17 Python companion tests**, and **15 Safari tests** passed.
- TLS socket checks passed: valid secret; rejected wrong secret before API access; 2 MiB byte-exact upload/response; preserved API error status; forbidden routes/headers and invalid frame rejection; cancellation; shutdown; Bonjour resolution without specifying an IP.
- Real Python API integration over TLS passed using an isolated synthetic screenshot library and fake Trash: library, PNG retrieval, save retry without duplicate exports, simulated clipboard acknowledgement, session reset, reviewed cleanup, preserved current-session file, and missing-source response.
- Mac build and its isolated self-test passed. No owner screenshots or system screenshot settings were changed; the self-test uses a private test pasteboard.
- iPad device archive succeeded unsigned. Bundle versions, Bonjour declarations, and `PrivacyInfo.xcprivacy` verified inside the produced archive.
- Website desktop and 390px mobile layout, internal links, JavaScript syntax, setup route and privacy wording checked. Published pages verified through Chrome. A separate command-line HTTP verification received 403, so a byte-for-byte live hash comparison is not claimed.
- `git diff --check` passed.
- Device availability check reported the physical **iPad (87) unavailable**; connected QA devices were simulators. No physical installation or radio-path test was attempted.

Logs and screenshots: `work/nearby-validation/` (ignored local artifacts).

Development outputs:

- `build/nearby-development/Ludwig's Annotated Screenshots.app` — ad-hoc-signed development Mac build; uses system Python, not the self-contained release helper.
- `build/nearby-development/Ludwig-1.1-19.xcarchive` — unsigned iPad archive, not an installable App Store update.

## Required before release

1. Test distribution prepared on 11 November: signed iPad build installed and launched; self-contained, notarized Mac ZIP ready. Transfer and install the Mac build on the MacBook, keeping a recoverable copy of the working app. Confirm existing drafts remain available.
2. With updated Mac and iPad apps, scan **Nearby** inside the iPad app. Test capture → Pencil/text → Done → actual Mac clipboard paste, a batch, and a save retry after interruption.
3. Test **different Wi-Fi networks** with Wi-Fi/Bluetooth enabled and devices nearby, plus an actual client-isolated guest network. Loopback and simulator tests do not exercise Apple Wireless Direct Link between physical radios.
4. Test a Wi-Fi change, sleep/wake, app relaunch, switching Mac Studio/MacBook with fresh QR, and denied/re-enabled Local Network permission. Confirm old drafts survive.
5. Check legacy Safari/iPad 1.0 using its explicit private-network mode.
6. Update public privacy/setup and App Store description/review notes to distinguish encrypted Nearby from legacy HTTP. Sign/notarize/verify the Mac download; upload the iPad build and obtain review approval before replacing public links. Keep current US-first distribution unless the owner changes it.

Nearby requires compatible nearby Apple devices with radios and permissions enabled. It is designed to avoid dependence on a shared router, not a guarantee of operation under every hardware, radio, VPN, or managed-device restriction. Safari cannot use this native transport.

## Search visibility follow-up

The full-name search already works. The website now has an explicit screenshot-markup title/description, direct App Store links, an iPad Smart App Banner and a sitemap entry for `/setup`.

For the next App Store version, consider replacing the generic subtitle **Capture. Mark. Paste.** with **Pencil markup for Mac captures**, retaining the existing name. Review keywords alongside the final subtitle so they cover relevant uses without wasting space on repeated words. This is a proposal, not a live metadata edit or a ranking promise. Apple documents name/subtitle/keyword behavior at https://developer.apple.com/app-store/product-page/.

References: https://developer.apple.com/documentation/network/nwparameters/includepeertopeer and https://developer.apple.com/documentation/technotes/tn3213-moving-from-multipeer-connectivity-to-network-framework.
