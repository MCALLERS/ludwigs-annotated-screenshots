# Release procedure

1. Update versions in scripts/build.sh, NativeiPad/generate-project.py, and visible beta labels. Regenerate the Xcode project.
2. Run Python, Safari, native simulator, and Mac self-tests. Exercise the complete workflow on a real iPad with synthetic screenshots, including three captures, retry, reconnect, and final queue clearing.
3. Build the signed self-contained Mac app with scripts/package-mac.sh. Run scripts/verify-packaged-companion.py against it. Verify all Mach-O dependencies are bundled or system-provided and support the stated minimum OS.
4. Notarize the signed app zip using a locally configured notarytool Keychain profile. Staple the accepted ticket to the app. Create a DMG containing the app, an Applications link, setup guide, and license. Sign/notarize/staple the DMG. Validate with `stapler validate` and `spctl --assess --type execute` on the app.
5. Audit exactly the files staged for Git: no screenshots, pairing keys, private paths, device identifiers, certificates, logs, or runtime state. Push the reviewed MIT source and publish the signed DMG plus SHA-256 checksum as a GitHub prerelease. Download it again, compare checksums, mount it, and verify the downloaded app signature and runtime.
6. Archive the iPad Release scheme with your Apple team, then upload through Xcode’s App Store Connect distribution. The listing is **Ludwig's Annotated Screenshots**, bundle `com.mcallers.screenshottool.ipad`.
7. Complete TestFlight test information, privacy URL, review notes, and review contact. Create an external beta group, submit its first build for Beta App Review, then enable a public invitation link after approval. Do not claim availability while processing or awaiting review.

Keep signing credentials, notary profiles, and Apple review contact information outside source control. Apple account agreements and account-holder compliance declarations must be handled by the account holder.

## Rename compatibility (0.5.1)

The app bundles and display names are `Ludwig's Annotated Screenshots`; the Mac executable remains `ScreenshotTool` and the native iPad module/executable remains `ScreenshotToolNative`. Keep the existing Mac and iPad bundle identifiers, Keychain service, library and state directories, and wire protocol. The internal frozen helper name and the legacy `/pony.png` asset alias are retained for compatibility. Do not rename or recreate the App Store Connect app record.

The new Mac app has a different bundle filename. Quit the old companion before opening it; do not run both versions together. Installation and physical-device capture/markup/paste verification remain separate from build and automated test validation.

## Current review notes

For the 1.1 update, use [App Store 1.1 metadata and review instructions](APP-STORE-1.1.md). The current release adds encrypted Nearby mode using Apple system TLS; legacy Safari/iPad 1.0 retains unencrypted local HTTP. Preserve this distinction in website copy, privacy disclosures, and review notes.

The owner authorized release on 11 November after successful physical different-network testing and the build 21 latency improvement. Actual isolated guest-network, broad hardware, and extended batch/sleep-wake testing remain unverified; do not describe them as passed or promise operation on every network. The App Store update must complete Apple review before being described as live.
