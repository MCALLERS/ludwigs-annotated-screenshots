# App Store 1.1 (21) update

Release authorized by the owner on 11 November 2026 following physical different-network testing. Preserve existing free pricing, US-only availability, review contact, and automatic release after approval. Submission status must be verified separately from upload.

## Verified submission

Submitted 11 November 2026 at 6:15 PM EST. App Store Connect confirmed **Waiting for Review** for **1.1 (21)**, with automatic release after approval. Submission ID: `7bdcaa4e-d1bb-4013-9286-0b2ccdc15fee`. The public iPad version remains 1.0 until Apple approves and releases the update.

Submission details: https://appstoreconnect.apple.com/apps/6827539095/distribution/reviewsubmissions/details/7bdcaa4e-d1bb-4013-9286-0b2ccdc15fee

## What is new

New Nearby pairing connects your iPad to the Mac companion using encrypted transfers. Keep Wi-Fi and Bluetooth on and both apps open; the devices can be on different Wi-Fi networks.

This update also fixes delayed screenshot refresh after re-pairing and adds clearer connection status and error messages.

Requires Mac companion 0.6.0 or later for Nearby. Existing local-network pairing remains available for compatibility.

## Description

Make your point. Right on the picture.

Ludwig's Annotated Screenshots turns a Mac screenshot into something you can draw on, explain, and send back to your conversation. Circle the detail. Sketch a change. Give a design a grade and say why.

Requires the free Ludwig's Mac companion, an Apple silicon Mac running macOS 14 or later, and an iPad running iPadOS 18 or later. With Mac companion 0.6.0 or later, choose Nearby for encrypted pairing between nearby devices. Keep Wi-Fi and Bluetooth enabled and both apps open. Nearby is designed to connect without relying on a shared router; network and device restrictions can still affect connectivity. Download the Mac companion and find setup instructions at https://screenshot.bombadillo-ai.com/.

CAPTURE. MARK. PASTE.
Press Shift-Command-4 on your Mac. The capture appears on your paired iPad. Annotate it, then tap Done. Wait for "Copied on your Mac" and press Command-V wherever you want to share an image.

PUT YOUR JUDGMENT ON THE SCREENSHOT
Draw with Apple Pencil, or enable finger drawing. Add circles, arrows, handwritten grades, and reasons. Use two fingers to pan and zoom, and Undo or Redo as you work.

TYPE IT OR SAY IT
Choose Text / voice, tap where the note belongs, and type or use the iPad keyboard's Dictation microphone. Review your words, choose a text size, and add the note. Drag it to reposition it; tap to edit or delete it. Dictation availability depends on your device, keyboard, language, and settings.

KEEP THE FEEDBACK MOVING
Work through several captures with Done & Next, browse earlier screenshots, and return to saved drafts. Clear queue starts a fresh count without deleting your images. Finished annotations are separate PNGs on your Mac, alongside your unchanged originals.

CHOOSE THE CONVERSATION
Paste the finished PNG into an AI chat, a message, or another app that accepts images. For a batch, attach the finished files from Documents > Screenshot Tool > Ready. Ludwig does not send messages or prompts for you.

YOUR DEVICES, YOUR FILES
No Ludwig account, advertising, analytics SDK, or developer-operated cloud relay. Nearby transfers travel directly between your Mac and iPad over an encrypted, authenticated connection. Legacy pairing and Safari use authenticated, unencrypted local HTTP and need a trusted private network. The Mac retains that legacy service for compatibility; Nearby does not encrypt simultaneous legacy traffic. You choose when to share them with another service. Apple's Dictation and any system backup or sync settings follow their own privacy policies.

An example says a lot. Your notes say why.

## Review notes

This update adds encrypted Nearby pairing and fixes delayed refresh after re-pairing. It requires the free Mac companion 0.6.0 or later. No app account, purchase, subscription, or reviewer login is required.

Mac download (Developer ID signed and notarized):
https://github.com/MCALLERS/ludwigs-annotated-screenshots/releases/download/v0.6.0/Ludwigs-Annotated-Screenshots-0.6.0-arm64.dmg

Setup: https://screenshot.bombadillo-ai.com/setup
Requirements: Apple silicon Mac, macOS 14 or later; iPad, iPadOS 18 or later. Apple Pencil is optional.

1. Install the Mac companion into Applications and open it. Choose Set up screenshot folder and allow Documents and Local Network access. Keep the Mac awake and both apps open.
2. On Mac, open Connect iPad and choose Nearby · iPad 1.1+. Keep Wi-Fi and Bluetooth enabled on both devices. In the iPad app, choose Connect your Mac / the link button, then Scan Mac QR code. Allow Camera and Local Network access. Scan the locally generated QR; there is no shared demo key. Never post or share a pairing QR.
3. Capture an area on Mac with Shift-Command-4 without Control. The screenshot appears on the iPad. Draw with Pencil or enable Finger drawing. Text / voice adds typed notes or text from Apple's keyboard Dictation; the app does not record audio. Two fingers pan and zoom.
4. Tap Done, wait for Copied on your Mac, then press Command-V in an app that accepts images. The PNG is also in Documents/Screenshot Tool/Ready; the original remains in Inbox.
5. Capture several images to exercise Done & Next and Browse. Clear queue resets the count without deleting files. Session cleanup previews older files before moving them to Mac Trash.

Nearby uses Network.framework Bonjour discovery with includePeerToPeer and TLS 1.2 PSK using Apple's system cryptography (Security/CryptoKit), with AES-128-GCM and HKDF-SHA256. No proprietary cryptographic implementation is included. Pairing authenticates both peers; screenshot data does not pass through a developer-operated server. Camera access is for QR scanning only. No advertising, analytics SDK, app account, or direct AI integration is present. Users choose where to paste or upload the finished image.

The Mac's Safari / iPad 1.0 mode retains authenticated, unencrypted local HTTP for compatibility and requires a trusted private network. Nearby does not encrypt simultaneous legacy HTTP traffic. Local drafts and pairing are preserved across updates. Data collection remains unchanged.

Physical testing confirmed MacBook/iPad capture, annotation, save and paste across different Wi-Fi networks, and faster arrival after the polling fix. This is not a guarantee for every guest network or managed-device configuration. No demo library or Photos import is included; the Mac companion is needed to review the workflow.

## Encryption

The implementation uses Apple system cryptography only; `ITSAppUsesNonExemptEncryption` remains false. Apple guidance: https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance and https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations. No new data collection or territory changes.
