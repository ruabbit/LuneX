# Security.framework identity spike

This isolated macOS executable verifies the client-identity primitives needed by
the native pairing runtime:

- non-persistent RSA-2048 key generation with Security.framework;
- repository-owned DER encoding of an X.509 v3 self-signed certificate;
- SHA-256 with RSA PKCS#1 v1.5 certificate and payload signatures;
- certificate parsing and public-key extraction with Security.framework.

The spike never requests permanent key storage, calls Keychain APIs, invokes a
`ClientIdentityStore`, writes key material, or contacts a host.

Run it from the repository root:

```sh
mkdir -p build/identity-spike
xcrun swiftc -framework Security \
  Tools/IdentitySpike/main.swift \
  -o build/identity-spike/lunex-identity-spike
build/identity-spike/lunex-identity-spike
```
