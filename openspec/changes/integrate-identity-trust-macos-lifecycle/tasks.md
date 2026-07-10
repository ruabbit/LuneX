## 1. Identity storage

- [x] 1.1 Implement `JSONFileClientIdentityStore` with atomic `0600` writes
- [x] 1.2 Add Debug-file/Release-Keychain store selection
- [x] 1.3 Add an opt-in real Keychain round-trip integration test
- [x] 1.4 Run the real Keychain test once, then keep normal tests on file/in-memory stores

## 2. Pinned HTTPS

- [x] 2.1 Implement exact leaf-certificate URLSession challenge handling
- [x] 2.2 Require host pins for app-list and artwork requests
- [x] 2.3 Require host pins for launch and stop requests
- [x] 2.4 Add trust-decision and request-routing tests

## 3. macOS runtime lifecycle

- [x] 3.1 Attach the AppKit lifecycle monitor to the SwiftUI window
- [x] 3.2 Publish live drawable size, visibility, focus, display, and EDR state
- [x] 3.3 Synchronize lifecycle state into AppModel render state
- [x] 3.4 Reconfigure Metal pause/throttle and EDR behavior on updates
- [x] 3.5 Add lifecycle synchronization tests

## 4. Verification and tracking

- [x] 4.1 Validate OpenSpec and run normal tests without Keychain access
- [x] 4.2 Build macOS, fixed iPhone, tvOS, and visionOS targets with isolated DerivedData
- [x] 4.3 Run the macOS app and verify imported hosts still load
- [x] 4.4 Update planning files, commit, and push
